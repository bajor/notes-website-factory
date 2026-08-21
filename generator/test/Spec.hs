{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Codec.Picture (Image, PixelRGB8 (PixelRGB8), PixelRGBA8 (PixelRGBA8), generateImage)
import Factory.Domain
import Factory.Evaluation (EvaluationResult (evaluationPassed), calculateDifference)
import Factory.Geometry (boardMatrix, identityMatrix, multiplyMatrix)
import Factory.Interpreter (Resources (Resources), VisualResource (RasterResource, VectorResource), interpretOperators)
import Factory.Pipeline (outputCompanionPaths, validateOutputPath)
import Factory.Pdf (rejectDecode, rgbaImage)
import Factory.Site (validateScene)
import Factory.Vectorize (ImageDisposition (..), classifyImage, traceImage)
import Pdf.Content (Op (..), Operator)
import Pdf.Core (Object (Name, Number))
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit (assertFailure, testCase, (@?=))
import qualified Data.ByteString as ByteString
import qualified Data.Map.Strict as Map
import qualified Data.Scientific as Scientific
import qualified Data.Text as Text

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "freeform factory"
    [ geometryTests
    , interpreterTests
    , imageTests
    , vectorizationTests
    , validationTests
    , evaluationTests
    , pipelineTests
    ]

geometryTests :: TestTree
geometryTests =
  testGroup
    "geometry"
    [ testCase "identity matrix leaves another matrix unchanged" $ do
        let matrix = Matrix 2 0 0 3 10 20
        multiplyMatrix identityMatrix matrix @?= matrix
    , testCase "board matrix flips the PDF vertical axis" $
        boardMatrix (Coordinate 100) (Matrix 1 0 0 1 10 20)
          @?= Matrix 1 0 0 (-1) 10 80
    ]

interpreterTests :: TestTree
interpreterTests =
  testGroup
    "operator interpreter"
    [ testCase "image operators emit a board-space image node" $
        interpretOperators pageHeight imageResources [operator Op_cm [2, 0, 0, 3, 10, 20], (Op_Do, [Name "Im1"])]
          @?= Right [ImageNode (AssetId "asset-1") (Matrix 2 0 0 (-3) 10 80) 1 []]
    , testCase "mixed image operators preserve source order" $
        interpretOperators pageHeight mixedResources [(Op_Do, [Name "Raster"]), (Op_Do, [Name "Vector"])]
          @?= Right
            [ ImageNode (AssetId "asset-1") (Matrix 1 0 0 (-1) 0 100) 1 []
            , VectorArtworkNode [testVectorShape] (Matrix 1 0 0 (-1) 0 100) 1 []
            ]
    , testCase "a closed subpath remains the current point" $
        case interpretOperators pageHeight emptyResources closedCurveOperators of
          Right [PathNode commands _ _] -> commandAt 3 commands @?= Just (CurveTo (Point 10 90) (Point 30 80) (Point 40 60))
          result -> assertFailure ("unexpected interpreter result: " <> show result)
    , testCase "PDF text fails until font decoding is supported" $
        interpretOperators pageHeight emptyResources [(Op_BT, [])]
          @?= Left (UnsupportedOperator "PDF text requires font decoding and metrics")
    ]

imageTests :: TestTree
imageTests =
  testGroup
    "image decoding"
    [ testCase "declared RGB samples require three bytes per pixel" $
        case rgbaImage 1 1 3 "\NUL" Nothing of
          Left buildError -> buildError @?= UnsupportedImage "decoded image samples have the wrong length"
          Right _ -> assertFailure "RGB image unexpectedly accepted one sample byte"
    , testCase "image Decode arrays fail explicitly" $
        rejectDecode (Just (Name "DecodeArray"))
          @?= Left (UnsupportedImage "image Decode arrays are not supported")
    ]

vectorizationTests :: TestTree
vectorizationTests =
  testGroup
    "vectorization"
    [ testCase "opaque images remain raster" $
        classifyImage Nothing @?= Right PreserveRaster
    , testCase "rounded screenshots with nearly opaque masks remain raster" $
        classifyImage (Just (ByteString.pack (0 : replicate 999 255))) @?= Right PreserveRaster
    , testCase "transparent soft masks become vector artwork" $
        classifyImage (Just "\NUL\255\255\255") @?= Right TraceAsVector
    , testCase "ambiguous soft masks fail classification" $
        classifyImage (Just (ByteString.pack (replicate 6 254 <> replicate 994 255)))
          @?= Left (UnsupportedImage "soft-masked image is too opaque to classify safely")
    , testCase "a filled rectangle produces one closed vector path" $
        case traceImage solidVectorImage of
          Right [shape] -> unVectorPath (vectorPath shape) @?= "M0,0L1,0L1,1L0,1Z"
          result -> assertFailure ("unexpected trace result: " <> show result)
    , testCase "transparent holes remain separate closed contours" $
        case traceImage vectorImageWithHole of
          Right [shape] -> Text.count "M" (unVectorPath (vectorPath shape)) @?= 2
          result -> assertFailure ("unexpected trace result: " <> show result)
    ]

validationTests :: TestTree
validationTests =
  testGroup
    "scene validation"
    [ testCase "an image must reference a declared asset" $
        validateScene (sceneWith [] [ImageNode (AssetId "missing") identityMatrix 1 []])
          @?= Left (InvalidScene "image node references a missing asset")
    , testCase "a clip cannot hide a full-board raster image" $
        validateScene (sceneWith [testAsset] [ImageNode (assetId testAsset) (Matrix 100 0 0 100 0 0) 1 [fullPageClip]])
          @?= Left (InvalidScene "a full-board raster image is not allowed")
    , testCase "unreferenced raster assets are rejected" $
        validateScene (sceneWith [testAsset] [])
          @?= Left (InvalidScene "scene contains an unreferenced asset")
    , testCase "vector-only scenes are valid" $
        case validateScene (sceneWith [] [VectorArtworkNode [testVectorShape] identityMatrix 1 []]) of
          Right _ -> pure ()
          Left buildError -> assertFailure ("unexpected validation error: " <> show buildError)
    ]

evaluationTests :: TestTree
evaluationTests =
  testGroup
    "visual evaluation"
    [ testCase "a blank rendering fails against sparse reference ink" $
        evaluationPassed (calculateDifference sparseReference blankImage) @?= False
    ]

pipelineTests :: TestTree
pipelineTests =
  testGroup
    "pipeline paths"
    [ testCase "an output directory containing the repository is rejected" $
        validateOutputPath "/workspace/repository" "/workspace"
          @?= Left (IoError "DIST must not equal or contain the repository root")
    , testCase "an output directory inside the repository is accepted" $
        validateOutputPath "/workspace/repository" "/workspace/repository/dist"
          @?= Right ()
    , testCase "trailing separators do not put staging inside the output" $
        outputCompanionPaths "/workspace/repository/dist/"
          @?= ("/workspace/repository/dist", "/workspace/repository/dist.building", "/workspace/repository/dist.previous")
    ]

pageHeight :: Coordinate PdfSpace
pageHeight = Coordinate 100

emptyResources :: Resources
emptyResources = Resources Map.empty Map.empty

imageResources :: Resources
imageResources = Resources (Map.singleton "Im1" (RasterResource (AssetId "asset-1"))) Map.empty

mixedResources :: Resources
mixedResources =
  Resources
    ( Map.fromList
        [ ("Raster", RasterResource (AssetId "asset-1"))
        , ("Vector", VectorResource [testVectorShape])
        ]
    )
    Map.empty

testVectorShape :: VectorShape
testVectorShape = VectorShape (VectorPath "M0,0L1,0L1,1Z") (Color 0 0 0) 1

operator :: Op -> [Double] -> Operator
operator name values = (name, map (Number . Scientific.fromFloatDigits) values)

closedCurveOperators :: [Operator]
closedCurveOperators =
  [ operator Op_m [10, 10]
  , operator Op_l [20, 10]
  , (Op_h, [])
  , operator Op_v [30, 20, 40, 40]
  , (Op_S, [])
  ]

commandAt :: Int -> [PathCommand] -> Maybe PathCommand
commandAt index commands = case drop index commands of
  command : _ -> Just command
  [] -> Nothing

sceneWith :: [Asset] -> [SceneNode] -> Scene 'Unvalidated
sceneWith assets nodes = Scene (Coordinate 100) (Coordinate 100) assets nodes

testAsset :: Asset
testAsset = Asset (AssetId "asset-1") "assets/asset-1.png" 10 10

fullPageClip :: ClipPath
fullPageClip =
  ClipPath
    ClipNonZero
    [ MoveTo (Point 0 0)
    , LineTo (Point 100 0)
    , LineTo (Point 100 100)
    , LineTo (Point 0 100)
    , ClosePath
    ]

sparseReference :: Image PixelRGB8
sparseReference = generateImage pixel 100 100
  where
    pixel 0 0 = PixelRGB8 0 0 0
    pixel _ _ = PixelRGB8 255 255 255

blankImage :: Image PixelRGB8
blankImage = generateImage (\_ _ -> PixelRGB8 255 255 255) 100 100

solidVectorImage :: Image PixelRGBA8
solidVectorImage = generateImage (\_ _ -> PixelRGBA8 0 0 0 255) 2 2

vectorImageWithHole :: Image PixelRGBA8
vectorImageWithHole = generateImage pixel 3 3
  where
    pixel 1 1 = PixelRGBA8 0 0 0 0
    pixel _ _ = PixelRGBA8 0 0 0 255
