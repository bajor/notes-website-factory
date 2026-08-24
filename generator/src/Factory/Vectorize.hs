{-# LANGUAGE OverloadedStrings #-}

-- | Deterministically classify and trace embedded Freeform artwork.
module Factory.Vectorize
  ( ImageDisposition (..)
  , classifyImage
  , traceImage
  ) where

import Codec.Picture (Image, PixelRGBA8 (PixelRGBA8), imageHeight, imageWidth, pixelAt)
import Data.ByteString (ByteString)
import Data.List (foldl', maximumBy, minimumBy)
import Data.Map.Strict (Map)
import Data.Ord (comparing)
import Data.Set (Set)
import Data.Text (Text)
import Data.Word (Word8)
import Factory.Domain
import Numeric (showFFloat)
import qualified Data.ByteString as ByteString
import qualified Data.Map.Strict as Map
import qualified Data.Set as Set
import qualified Data.Text as Text

data ImageDisposition = PreserveRaster | TraceAsVector
  deriving stock (Eq, Show)

data Style = Style Word8 Word8 Word8 Word8
  deriving stock (Eq, Ord, Show)

data GridPoint = GridPoint Int Int
  deriving stock (Eq, Ord, Show)

data Edge = Edge GridPoint GridPoint
  deriving stock (Eq, Ord, Show)

minimumTransparentFraction :: Double
minimumTransparentFraction = 0.02

maximumRasterTransparency :: Double
maximumRasterTransparency = 0.01

minimumTraceableAlpha :: Word8
minimumTraceableAlpha = 96

maximumVectorPoints :: Int
maximumVectorPoints = 500000

simplificationToleranceSquared :: Double
simplificationToleranceSquared = 1

classifyImage :: Maybe ByteString -> Either BuildError ImageDisposition
classifyImage Nothing = Right PreserveRaster
classifyImage (Just alpha)
  | ByteString.null alpha = Left (UnsupportedImage "soft mask is empty")
  | not hasNonzeroAlpha = Left (UnsupportedImage "soft mask contains no visible artwork")
  | not hasTraceableAlpha = Right PreserveRaster
  | transparentFraction <= maximumRasterTransparency = Right PreserveRaster
  | transparentFraction < minimumTransparentFraction = Left (UnsupportedImage "soft-masked image is too opaque to classify safely")
  | otherwise = Right TraceAsVector
  where
    samples = ByteString.unpack alpha
    hasNonzeroAlpha = any (> 0) samples
    hasTraceableAlpha = any (>= minimumTraceableAlpha) samples
    transparent = length (filter (< 255) samples)
    transparentFraction = fromIntegral transparent / fromIntegral (length samples)

traceImage :: Image PixelRGBA8 -> Either BuildError [VectorShape]
traceImage image
  | null shapes = Left (UnsupportedImage "vector artwork contains no visible shapes")
  | pointCount > maximumVectorPoints = Left (UnsupportedImage "vector artwork exceeds the point complexity limit")
  | otherwise = Right shapes
  where
    boundaries = collectBoundaries image
    shapes = map (shapeFromEdges (imageWidth image) (imageHeight image)) (Map.toAscList boundaries)
    pointCount = sum (map (Text.count "L" . unVectorPath . vectorPath) shapes)

collectBoundaries :: Image PixelRGBA8 -> Map Style (Set Edge)
collectBoundaries image = rows 0 Map.empty
  where
    width = imageWidth image
    height = imageHeight image
    rows y boundaries
      | y == height = boundaries
      | otherwise = rows (y + 1) (columns 0 y boundaries)
    columns x y boundaries
      | x == width = boundaries
      | otherwise = columns (x + 1) y (addPixelEdges x y boundaries)
    addPixelEdges x y boundaries = case pixelStyle (pixelAt image x y) of
      Nothing -> boundaries
      Just style -> foldl' (insertEdge style) boundaries (boundaryEdges style x y)
    boundaryEdges style x y =
      [ Edge (GridPoint x y) (GridPoint (x + 1) y) | styleAt x (y - 1) /= Just style ]
        <> [Edge (GridPoint (x + 1) y) (GridPoint (x + 1) (y + 1)) | styleAt (x + 1) y /= Just style]
        <> [Edge (GridPoint (x + 1) (y + 1)) (GridPoint x (y + 1)) | styleAt x (y + 1) /= Just style]
        <> [Edge (GridPoint x (y + 1)) (GridPoint x y) | styleAt (x - 1) y /= Just style]
    styleAt x y
      | x < 0 || y < 0 || x >= width || y >= height = Nothing
      | otherwise = pixelStyle (pixelAt image x y)

insertEdge :: Style -> Map Style (Set Edge) -> Edge -> Map Style (Set Edge)
insertEdge style boundaries edge = Map.insertWith Set.union style (Set.singleton edge) boundaries

pixelStyle :: PixelRGBA8 -> Maybe Style
pixelStyle (PixelRGBA8 red green blue alpha)
  | alpha < minimumTraceableAlpha = Nothing
  | otherwise = Just (Style (quantize 32 red) (quantize 32 green) (quantize 32 blue) 255)

quantize :: Int -> Word8 -> Word8
quantize step value = fromIntegral (min 255 (((fromIntegral value + step `div` 2) `div` step) * step) :: Int)

shapeFromEdges :: Int -> Int -> (Style, Set Edge) -> VectorShape
shapeFromEdges width height (style, edges) =
  VectorShape
    { vectorPath = VectorPath (pathText width height (traceContours edges))
    , vectorColor = styleColor style
    , vectorOpacity = styleOpacity style
    }

traceContours :: Set Edge -> [[GridPoint]]
traceContours = consumeContours . edgeMap

edgeMap :: Set Edge -> Map GridPoint (Set GridPoint)
edgeMap = Set.foldl' add Map.empty
  where
    add adjacency (Edge start end) = Map.insertWith Set.union start (Set.singleton end) adjacency

consumeContours :: Map GridPoint (Set GridPoint) -> [[GridPoint]]
consumeContours adjacency
  | Map.null adjacency = []
  | otherwise =
      let (start, destinations) = Map.findMin adjacency
          next = Set.findMin destinations
          remaining = removeTransition start next adjacency
          (contour, rest) = walkContour start start next [start] remaining
       in simplifyClosed contour : consumeContours rest

walkContour :: GridPoint -> GridPoint -> GridPoint -> [GridPoint] -> Map GridPoint (Set GridPoint) -> ([GridPoint], Map GridPoint (Set GridPoint))
walkContour origin previous current reversed remaining
  | current == origin = (reverse reversed, remaining)
  | otherwise = case nextPoint previous current remaining of
      Nothing -> (reverse (current : reversed), remaining)
      Just next -> walkContour origin current next (current : reversed) (removeTransition current next remaining)

nextPoint :: GridPoint -> GridPoint -> Map GridPoint (Set GridPoint) -> Maybe GridPoint
nextPoint previous current adjacency = case Map.lookup current adjacency of
  Nothing -> Nothing
  Just destinations -> Just (minimumBy (comparing turnRank) (Set.toList destinations))
  where
    incoming = direction previous current
    turnRank next = turnPreference ((direction current next - incoming) `mod` 4)

removeTransition :: GridPoint -> GridPoint -> Map GridPoint (Set GridPoint) -> Map GridPoint (Set GridPoint)
removeTransition start end = Map.update remove start
  where
    remove destinations =
      let remaining = Set.delete end destinations
       in if Set.null remaining then Nothing else Just remaining

direction :: GridPoint -> GridPoint -> Int
direction (GridPoint x1 y1) (GridPoint x2 y2)
  | x2 > x1 = 0
  | y2 > y1 = 1
  | x2 < x1 = 2
  | otherwise = 3

turnPreference :: Int -> Int
turnPreference turn = case turn of
  1 -> 0
  0 -> 1
  3 -> 2
  _ -> 3

simplifyClosed :: [GridPoint] -> [GridPoint]
simplifyClosed points
  | length cleaned <= 4 = cleaned
  | otherwise = init (simplifyOpen firstHalf) <> init (simplifyOpen secondHalf)
  where
    cleaned = removeCollinear points
    anchor = head cleaned
    farthestIndex = fst (maximumBy (comparing (distanceSquared anchor . snd)) (zip [0 ..] cleaned))
    firstHalf = take (farthestIndex + 1) cleaned
    secondHalf = drop farthestIndex cleaned <> [anchor]

simplifyOpen :: [GridPoint] -> [GridPoint]
simplifyOpen points
  | length points <= 2 = points
  | maximumDistance <= simplificationToleranceSquared = [start, end]
  | otherwise = init (simplifyOpen left) <> simplifyOpen right
  where
    start = head points
    end = last points
    middle = zip [1 ..] (tail (init points))
    (relativeIndex, _) = maximumBy (comparing (lineDistanceSquared start end . snd)) middle
    maximumDistance = lineDistanceSquared start end (points !! relativeIndex)
    left = take (relativeIndex + 1) points
    right = drop relativeIndex points

removeCollinear :: [GridPoint] -> [GridPoint]
removeCollinear points =
  [ current
  | (previous, current, next) <- zip3 (last points : init points) points (tail points <> [head points])
  , not (collinear previous current next)
  ]

collinear :: GridPoint -> GridPoint -> GridPoint -> Bool
collinear (GridPoint ax ay) (GridPoint bx by) (GridPoint cx cy) =
  (bx - ax) * (cy - by) == (by - ay) * (cx - bx)

distanceSquared :: GridPoint -> GridPoint -> Double
distanceSquared (GridPoint ax ay) (GridPoint bx by) =
  fromIntegral ((bx - ax) ^ (2 :: Int) + (by - ay) ^ (2 :: Int))

lineDistanceSquared :: GridPoint -> GridPoint -> GridPoint -> Double
lineDistanceSquared (GridPoint ax ay) (GridPoint bx by) (GridPoint px py)
  | lengthSquared == 0 = distanceSquared (GridPoint ax ay) (GridPoint px py)
  | otherwise = cross * cross / lengthSquared
  where
    dx = fromIntegral (bx - ax)
    dy = fromIntegral (by - ay)
    offsetX = fromIntegral (px - ax)
    offsetY = fromIntegral (py - ay)
    cross = dy * offsetX - dx * offsetY
    lengthSquared = dx * dx + dy * dy

pathText :: Int -> Int -> [[GridPoint]] -> Text
pathText width height = Text.intercalate " " . map contourText
  where
    contourText [] = ""
    contourText (point : rest) = "M" <> pointText point <> foldMap (("L" <>) . pointText) rest <> "Z"
    pointText (GridPoint x y) = decimal (fromIntegral x / fromIntegral width) <> "," <> decimal (fromIntegral y / fromIntegral height)

decimal :: Double -> Text
decimal value = trimDecimal (Text.pack (showFFloat (Just 6) value ""))

trimDecimal :: Text -> Text
trimDecimal value =
  let withoutZeros = Text.dropWhileEnd (== '0') value
   in if Text.isSuffixOf "." withoutZeros then Text.dropEnd 1 withoutZeros else withoutZeros

styleColor :: Style -> Color
styleColor (Style red green blue _) = Color (channel red) (channel green) (channel blue)
  where
    channel = (/ 255) . fromIntegral

styleOpacity :: Style -> Double
styleOpacity (Style _ _ _ alpha) = fromIntegral alpha / 255
