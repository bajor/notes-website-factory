{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

module Main (main) where

import Codec.Picture (Image, PixelRGB8 (PixelRGB8), generateImage)
import Factory.Domain
import Factory.Evaluation (EvaluationResult (evaluationPassed), calculateDifference)
import Factory.Geometry (boardMatrix, identityMatrix, multiplyMatrix)
import Factory.Interpreter (Resources (Resources), interpretOperators)
import Factory.Pipeline (outputCompanionPaths, validateOutputPath)
import Factory.Pdf (rejectDecode, rgbaImage)
import Factory.Site (validateScene)
import Pdf.Content (Op (..), Operator)
import Pdf.Core (Object (Name, Number))
import Test.Tasty (TestTree, defaultMain, testGroup)
import Test.Tasty.HUnit (assertFailure, testCase, (@?=))
import qualified Data.Map.Strict as Map
import qualified Data.Scientific as Scientific

main :: IO ()
main = defaultMain tests

tests :: TestTree
tests =
  testGroup
    "freeform factory"
    [ geometryTests
    , interpreterTests
    , imageTests
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
imageResources = Resources (Map.singleton "Im1" (AssetId "asset-1")) Map.empty

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
