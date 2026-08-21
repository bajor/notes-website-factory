{-# LANGUAGE OverloadedStrings #-}

-- | Interpret PDF drawing operators as immutable scene nodes.
--
-- This module demonstrates a functional state machine. 'foldM' visits one
-- operator at a time. Each visit receives the old state and returns a new
-- state. Nothing is changed in place, which makes every transition testable.
module Factory.Interpreter
  ( Resources (..)
  , VisualResource (..)
  , interpretOperators
  ) where

import Control.Monad (foldM)
import Data.Map.Strict (Map)
import Data.Text (Text)
import Factory.Domain
import Factory.Geometry
import Pdf.Content (Op (..), Operator)
import Pdf.Core (Name, Object)
import Pdf.Core.Name (toByteString)
import Pdf.Core.Object.Util (nameValue, realValue)
import qualified Data.Map.Strict as Map
import qualified Data.Text as Text
import qualified Data.Text.Encoding as TextEncoding

data Resources = Resources
  { resourceImages :: Map Name VisualResource
  , resourceAlpha :: Map Name Double
  }
  deriving stock (Eq, Show)

data VisualResource
  = RasterResource AssetId
  | VectorResource [VectorShape]
  deriving stock (Eq, Show)

data GraphicsState = GraphicsState
  { currentMatrix :: Matrix
  , currentClips :: [ClipPath]
  , currentOpacity :: Double
  , currentFill :: Color
  , currentStroke :: Color
  , currentLineWidth :: Double
  }
  deriving stock (Eq, Show)

data Machine = Machine
  { machineGraphics :: GraphicsState
  , machineStack :: [GraphicsState]
  , machinePath :: [PathCommand]
  , machinePendingClip :: Maybe ClipRule
  , machineNodes :: [SceneNode]
  }
  deriving stock (Eq, Show)

initialGraphics :: GraphicsState
initialGraphics =
  GraphicsState
    { currentMatrix = identityMatrix
    , currentClips = []
    , currentOpacity = 1
    , currentFill = Color 0 0 0
    , currentStroke = Color 0 0 0
    , currentLineWidth = 1
    }

initialMachine :: Machine
initialMachine = Machine initialGraphics [] [] Nothing []

interpretOperators :: Coordinate PdfSpace -> Resources -> [Operator] -> Either BuildError [SceneNode]
interpretOperators pageHeight resources operators = do
  final <- foldM (step pageHeight resources) initialMachine operators
  if null (machineStack final)
    then Right (reverse (machineNodes final))
    else Left (GraphicsStateError "content stream ended before every q had a matching Q")

step :: Coordinate PdfSpace -> Resources -> Machine -> Operator -> Either BuildError Machine
step pageHeight resources machine operator = case operator of
  (Op_q, []) -> Right machine {machineStack = machineGraphics machine : machineStack machine}
  (Op_Q, []) -> restoreGraphics machine
  (Op_cm, values) -> do
    matrix <- matrixFrom values
    let graphics = machineGraphics machine
    Right machine {machineGraphics = graphics {currentMatrix = multiplyMatrix matrix (currentMatrix graphics)}}
  (Op_gs, [value]) -> setAlpha resources machine value
  (Op_w, [value]) -> setLineWidth machine value
  (Op_g, [value]) -> setGray True machine value
  (Op_G, [value]) -> setGray False machine value
  (Op_rg, values) -> setRgb True machine values
  (Op_RG, values) -> setRgb False machine values
  (Op_k, values) -> setCmyk True machine values
  (Op_K, values) -> setCmyk False machine values
  (Op_m, values) -> appendPoint pageHeight machine MoveTo values
  (Op_l, values) -> appendPoint pageHeight machine LineTo values
  (Op_c, values) -> appendCurve pageHeight machine values
  (Op_v, values) -> appendShorthandCurve pageHeight True machine values
  (Op_y, values) -> appendShorthandCurve pageHeight False machine values
  (Op_h, []) -> Right machine {machinePath = machinePath machine <> [ClosePath]}
  (Op_re, values) -> appendRectangle pageHeight machine values
  (Op_W, []) -> Right machine {machinePendingClip = Just ClipNonZero}
  (Op_W_star, []) -> Right machine {machinePendingClip = Just ClipEvenOdd}
  (Op_n, []) -> Right (finishWithoutPaint machine)
  (Op_S, []) -> Right (finishWithPaint machine Nothing True NonZero)
  (Op_s, []) -> Right (finishWithPaint (closeCurrentPath machine) Nothing True NonZero)
  (Op_f, []) -> Right (finishWithPaint machine (Just (currentFill (machineGraphics machine))) False NonZero)
  (Op_F, []) -> Right (finishWithPaint machine (Just (currentFill (machineGraphics machine))) False NonZero)
  (Op_f_star, []) -> Right (finishWithPaint machine (Just (currentFill (machineGraphics machine))) False EvenOdd)
  (Op_B, []) -> Right (finishWithPaint machine (Just (currentFill (machineGraphics machine))) True NonZero)
  (Op_B_star, []) -> Right (finishWithPaint machine (Just (currentFill (machineGraphics machine))) True EvenOdd)
  (Op_b, []) -> Right (finishWithPaint (closeCurrentPath machine) (Just (currentFill (machineGraphics machine))) True NonZero)
  (Op_b_star, []) -> Right (finishWithPaint (closeCurrentPath machine) (Just (currentFill (machineGraphics machine))) True EvenOdd)
  (Op_Do, [value]) -> emitImage pageHeight resources machine value
  (Op_BT, []) -> Left (UnsupportedOperator "PDF text requires font decoding and metrics")
  (Op_ri, _) -> Right machine
  (Op_BMC, _) -> Right machine
  (Op_BDC, _) -> Right machine
  (Op_EMC, _) -> Right machine
  _ -> Left (UnsupportedOperator (Text.pack (show operator)))

restoreGraphics :: Machine -> Either BuildError Machine
restoreGraphics machine = case machineStack machine of
  [] -> Left (GraphicsStateError "Q tried to restore an empty graphics-state stack")
  previous : rest -> Right machine {machineGraphics = previous, machineStack = rest}

matrixFrom :: [Object] -> Either BuildError Matrix
matrixFrom values = case traverse number values of
  Right [a, b, c, d, e, f] -> Right (Matrix a b c d e f)
  _ -> Left (PdfStructureError "matrix operator expected six numbers")

number :: Object -> Either BuildError Double
number value = maybe (Left (PdfStructureError "operator expected a number")) Right (realValue value)

pointFrom :: Coordinate PdfSpace -> Matrix -> [Object] -> Either BuildError (Point BoardSpace)
pointFrom height matrix values = case traverse number values of
  Right [x, y] -> Right (pdfPointToBoard height (applyMatrix matrix (Point (Coordinate x) (Coordinate y))))
  _ -> Left (PdfStructureError "path operator expected two numbers")

appendPoint :: Coordinate PdfSpace -> Machine -> (Point BoardSpace -> PathCommand) -> [Object] -> Either BuildError Machine
appendPoint pageHeight machine constructor values = do
  point <- pointFrom pageHeight (currentMatrix (machineGraphics machine)) values
  Right machine {machinePath = machinePath machine <> [constructor point]}
appendCurve :: Coordinate PdfSpace -> Machine -> [Object] -> Either BuildError Machine
appendCurve height machine values = case chunksOfTwo values of
  [first, second, end] -> do
    firstPoint <- pointFrom height matrix first
    secondPoint <- pointFrom height matrix second
    endPoint <- pointFrom height matrix end
    Right machine {machinePath = machinePath machine <> [CurveTo firstPoint secondPoint endPoint]}
  _ -> Left (PdfStructureError "curve operator expected six numbers")
  where
    matrix = currentMatrix (machineGraphics machine)

appendShorthandCurve :: Coordinate PdfSpace -> Bool -> Machine -> [Object] -> Either BuildError Machine
appendShorthandCurve height firstIsCurrent machine values = case chunksOfTwo values of
  [first, end] -> do
    firstPoint <- pointFrom height matrix first
    endPoint <- pointFrom height matrix end
    let current = currentPathPoint machine
        command = if firstIsCurrent then CurveTo current firstPoint endPoint else CurveTo firstPoint endPoint endPoint
    Right machine {machinePath = machinePath machine <> [command]}
  _ -> Left (PdfStructureError "shorthand curve operator expected four numbers")
  where
    matrix = currentMatrix (machineGraphics machine)

appendRectangle :: Coordinate PdfSpace -> Machine -> [Object] -> Either BuildError Machine
appendRectangle height machine values = case traverse number values of
  Right [x, y, width, rectangleHeight] ->
    let matrix = currentMatrix (machineGraphics machine)
        transformPoint px py = pdfPointToBoard height (applyMatrix matrix (Point (Coordinate px) (Coordinate py)))
        commands =
          [ MoveTo (transformPoint x y)
          , LineTo (transformPoint (x + width) y)
          , LineTo (transformPoint (x + width) (y + rectangleHeight))
          , LineTo (transformPoint x (y + rectangleHeight))
          , ClosePath
          ]
     in Right machine {machinePath = machinePath machine <> commands}
  _ -> Left (PdfStructureError "rectangle operator expected four numbers")

finishWithoutPaint :: Machine -> Machine
finishWithoutPaint = clearPath . applyPendingClip

finishWithPaint :: Machine -> Maybe Color -> Bool -> FillRule -> Machine
finishWithPaint machine fillColor hasStroke fillRule =
  clearPath (appendNode (applyPendingClip machine))
  where
    graphics = machineGraphics machine
    style =
      PaintStyle
        { paintFill = fmap (,fillRule) fillColor
        , paintStroke = if hasStroke then Just (currentStroke graphics) else Nothing
        , paintLineWidth = currentLineWidth graphics
        , paintOpacity = currentOpacity graphics
        }
    appendNode current
      | null (machinePath machine) = current
      | otherwise = current {machineNodes = PathNode (machinePath machine) style (currentClips graphics) : machineNodes current}

applyPendingClip :: Machine -> Machine
applyPendingClip machine = case machinePendingClip machine of
  Nothing -> machine
  Just rule ->
    let graphics = machineGraphics machine
        clip = ClipPath rule (machinePath machine)
     in machine {machineGraphics = graphics {currentClips = currentClips graphics <> [clip]}, machinePendingClip = Nothing}

clearPath :: Machine -> Machine
clearPath machine = machine {machinePath = [], machinePendingClip = Nothing}

closeCurrentPath :: Machine -> Machine
closeCurrentPath machine = machine {machinePath = machinePath machine <> [ClosePath]}

currentPathPoint :: Machine -> Point BoardSpace
currentPathPoint machine = case reverse (machinePath machine) of
  ClosePath : previous -> subpathStart previous
  MoveTo point : _ -> point
  LineTo point : _ -> point
  CurveTo _ _ point : _ -> point
  _ -> Point 0 0
  where
    subpathStart commands = case dropWhile (not . isMove) commands of
      MoveTo point : _ -> point
      _ -> Point 0 0
    isMove MoveTo {} = True
    isMove _ = False

emitImage :: Coordinate PdfSpace -> Resources -> Machine -> Object -> Either BuildError Machine
emitImage height resources machine value = do
  name <- maybe (Left (PdfStructureError "Do expected an image resource name")) Right (nameValue value)
  resource <- maybe (Left (PdfStructureError ("missing image resource " <> nameText name))) Right (Map.lookup name (resourceImages resources))
  let graphics = machineGraphics machine
      matrix = boardMatrix height (currentMatrix graphics)
      opacity = currentOpacity graphics
      clips = currentClips graphics
      node = case resource of
        RasterResource identifier -> ImageNode identifier matrix opacity clips
        VectorResource shapes -> VectorArtworkNode shapes matrix opacity clips
  Right machine {machineNodes = node : machineNodes machine}

setAlpha :: Resources -> Machine -> Object -> Either BuildError Machine
setAlpha resources machine value = do
  name <- maybe (Left (PdfStructureError "gs expected a graphics-state name")) Right (nameValue value)
  opacity <- maybe (Left (PdfStructureError ("missing ExtGState resource " <> nameText name))) Right (Map.lookup name (resourceAlpha resources))
  let graphics = machineGraphics machine
  Right machine {machineGraphics = graphics {currentOpacity = opacity}}

setLineWidth :: Machine -> Object -> Either BuildError Machine
setLineWidth machine value = do
  width <- number value
  let graphics = machineGraphics machine
  Right machine {machineGraphics = graphics {currentLineWidth = width}}
setGray :: Bool -> Machine -> Object -> Either BuildError Machine
setGray isFill machine value = do
  gray <- number value
  setColor isFill machine (Color gray gray gray)
setRgb :: Bool -> Machine -> [Object] -> Either BuildError Machine
setRgb isFill machine values = case traverse number values of
  Right [red, green, blue] -> setColor isFill machine (Color red green blue)
  _ -> Left (PdfStructureError "RGB operator expected three numbers")
setCmyk :: Bool -> Machine -> [Object] -> Either BuildError Machine
setCmyk isFill machine values = case traverse number values of
  Right [cyan, magenta, yellow, black] ->
    setColor isFill machine (Color (1 - min 1 (cyan + black)) (1 - min 1 (magenta + black)) (1 - min 1 (yellow + black)))
  _ -> Left (PdfStructureError "CMYK operator expected four numbers")
setColor :: Bool -> Machine -> Color -> Either BuildError Machine
setColor isFill machine color =
  let graphics = machineGraphics machine
      updated = if isFill then graphics {currentFill = color} else graphics {currentStroke = color}
   in Right machine {machineGraphics = updated}
chunksOfTwo :: [a] -> [[a]]
chunksOfTwo [] = []
chunksOfTwo (first : second : rest) = [first, second] : chunksOfTwo rest
chunksOfTwo [_] = []

nameText :: Name -> Text
nameText = TextEncoding.decodeLatin1 . toByteString
