{-# LANGUAGE OverloadedStrings #-}

-- | Produce evidence for the software-factory feedback loop.
--
-- The deployed page never uses a rendered PDF. During development, however,
-- a mature renderer is a useful oracle. We compare that oracle with a browser
-- screenshot of our generated DOM/SVG scene and keep the difference image
-- as evidence for the next parser iteration.
module Factory.Evaluation
  ( EvaluationResult (..)
  , calculateDifference
  , runVisualEvaluation
  ) where

import Codec.Picture
  ( Image (imageData, imageHeight, imageWidth)
  , PixelRGB8 (PixelRGB8)
  , convertRGB8
  , generateImage
  , readImage
  , writePng
  )
import Data.Aeson (encode, object, (.=))
import Data.Text (Text)
import Data.Word (Word8)
import Factory.Domain (BuildError (EvaluationError))
import Control.Exception (IOException, try)
import System.Directory (createDirectoryIfMissing, doesPathExist, makeAbsolute, removePathForcibly)
import System.Exit (ExitCode (ExitSuccess))
import System.Environment (lookupEnv)
import System.FilePath ((</>))
import System.Process (readProcessWithExitCode)
import qualified Data.ByteString.Lazy as LazyByteString
import qualified Data.Text as Text
import qualified Data.Text.IO as Text
import qualified Data.Vector.Storable as Vector

data EvaluationResult = EvaluationResult
  { evaluationMeanError :: Double
  , evaluationPixelsWithinTolerance :: Double
  , evaluationInkRatio :: Double
  , evaluationPassed :: Bool
  }
  deriving stock (Eq, Show)

data ScaleEvaluation = ScaleEvaluation Int EvaluationResult

referenceDpis :: [Int]
referenceDpis = [18, 72]

maximumMeanError :: Double
maximumMeanError = 0.02

minimumPixelsWithinTolerance :: Double
minimumPixelsWithinTolerance = 0.96

minimumInkRatio :: Double
minimumInkRatio = 0.85

maximumInkRatio :: Double
maximumInkRatio = 1.15

pixelTolerance :: Int
pixelTolerance = 32

runVisualEvaluation :: FilePath -> FilePath -> FilePath -> IO (Either BuildError EvaluationResult)
runVisualEvaluation pdfPath siteDirectory reportDirectory = do
  reportExists <- doesPathExist reportDirectory
  if reportExists then removePathForcibly reportDirectory else pure ()
  createDirectoryIfMissing True reportDirectory
  absoluteSite <- makeAbsolute siteDirectory
  evaluated <- traverse (evaluateScale pdfPath absoluteSite reportDirectory) referenceDpis
  case sequence evaluated of
    Left buildError -> pure (Left buildError)
    Right scales -> do
      let result = aggregateResults scales
      writeReports reportDirectory scales result
      pure (Right result)

evaluateScale :: FilePath -> FilePath -> FilePath -> Int -> IO (Either BuildError ScaleEvaluation)
evaluateScale pdfPath absoluteSite reportDirectory dpi = do
  let suffix = "-" <> show dpi
      referenceStem = reportDirectory </> "reference" <> suffix
      referencePath = referenceStem <> ".png"
      generatedPath = reportDirectory </> "generated" <> suffix <> ".png"
      differencePath = reportDirectory </> "difference" <> suffix <> ".png"
  referenceExit <- runTool "pdftoppm" ["-singlefile", "-png", "-r", show dpi, pdfPath, referenceStem]
  case referenceExit of
    Left message -> pure (Left (EvaluationError message))
    Right () -> do
      reference <- readRgb referencePath
      case reference of
        Left message -> pure (Left (EvaluationError message))
        Right referenceImage -> do
          browserExit <- runBrowser absoluteSite generatedPath dpi (imageWidth referenceImage) (imageHeight referenceImage)
          case browserExit of
            Left message -> pure (Left (EvaluationError message))
            Right () -> fmap (ScaleEvaluation dpi) <$> compareImages referenceImage generatedPath differencePath

runBrowser :: FilePath -> FilePath -> Int -> Int -> Int -> IO (Either Text ())
runBrowser siteDirectory screenshotPath dpi width height = do
  browser <- maybe "chromium" id <$> lookupEnv "CHROMIUM"
  renderedDom <- runToolOutput browser (browserArguments <> ["--dump-dom", pageUrl])
  case renderedDom of
    Left message -> pure (Left message)
    Right html
      | not ("data-ready=\"true\"" `Text.isInfixOf` html) -> pure (Left "chromium did not report a completed scene")
      | otherwise -> runTool browser (browserArguments <> ["--screenshot=" <> screenshotPath, pageUrl])
  where
    pageUrl = "file://" <> siteDirectory </> "index.html" <> "?evaluation=" <> show dpi
    browserArguments =
      [ "--headless"
      , "--no-sandbox"
      , "--disable-gpu"
      , "--hide-scrollbars"
      , "--allow-file-access-from-files"
      , "--virtual-time-budget=15000"
      , "--force-device-scale-factor=1"
      , "--window-size=" <> show width <> "," <> show height
      ]

runTool :: FilePath -> [String] -> IO (Either Text ())
runTool command arguments = do
  result <- runProcess command arguments
  pure $ case result of
    Left exception -> Left (Text.pack (command <> " failed: " <> show exception))
    Right (ExitSuccess, _, _) -> Right ()
    Right (_, _, standardError) -> Left (Text.pack (command <> " failed: " <> standardError))

runToolOutput :: FilePath -> [String] -> IO (Either Text Text)
runToolOutput command arguments = do
  result <- runProcess command arguments
  pure $ case result of
    Left exception -> Left (Text.pack (command <> " failed: " <> show exception))
    Right (ExitSuccess, standardOutput, _) -> Right (Text.pack standardOutput)
    Right (_, _, standardError) -> Left (Text.pack (command <> " failed: " <> standardError))

runProcess :: FilePath -> [String] -> IO (Either IOException (ExitCode, String, String))
runProcess command arguments = try (readProcessWithExitCode command arguments "")

readRgb :: FilePath -> IO (Either Text (Image PixelRGB8))
readRgb path = do
  decoded <- readImage path
  pure (either (Left . Text.pack) (Right . convertRGB8) decoded)

compareImages :: Image PixelRGB8 -> FilePath -> FilePath -> IO (Either BuildError EvaluationResult)
compareImages reference generatedPath differencePath = do
  generated <- readRgb generatedPath
  case generated of
    Left message -> pure (Left (EvaluationError message))
    Right generatedImage
      | dimensions reference /= dimensions generatedImage ->
          pure (Left (EvaluationError "reference and generated screenshots have different dimensions"))
      | otherwise -> do
          let result = calculateDifference reference generatedImage
              difference = differenceImage reference generatedImage
          writePng differencePath difference
          pure (Right result)

aggregateResults :: [ScaleEvaluation] -> EvaluationResult
aggregateResults scales =
  EvaluationResult
    { evaluationMeanError = maximum (map (evaluationMeanError . scaleResult) scales)
    , evaluationPixelsWithinTolerance = minimum (map (evaluationPixelsWithinTolerance . scaleResult) scales)
    , evaluationInkRatio = evaluationInkRatio (maximumByInkDistance (map scaleResult scales))
    , evaluationPassed = all (evaluationPassed . scaleResult) scales
    }
  where
    scaleResult (ScaleEvaluation _ result) = result
    maximumByInkDistance (first : rest) = foldl choose first rest
    maximumByInkDistance [] = EvaluationResult 1 0 0 False
    choose left right
      | abs (evaluationInkRatio right - 1) > abs (evaluationInkRatio left - 1) = right
      | otherwise = left

calculateDifference :: Image PixelRGB8 -> Image PixelRGB8 -> EvaluationResult
calculateDifference reference generated =
  EvaluationResult meanError withinRatio inkRatio passed
  where
    referenceData = imageData reference
    generatedData = imageData generated
    totalDifference = Vector.ifoldl' (\total index left -> total + abs (fromIntegral left - fromIntegral (generatedData Vector.! index) :: Int)) 0 referenceData
    channelCount = Vector.length referenceData
    meanError = fromIntegral totalDifference / fromIntegral (channelCount * 255)
    pixelCount = imageWidth reference * imageHeight reference
    withinCount = countPixelsWithin reference generated pixelCount
    withinRatio = fromIntegral withinCount / fromIntegral pixelCount
    referenceInk = imageInk reference
    generatedInk = imageInk generated
    inkRatio = if referenceInk == 0 then if generatedInk == 0 then 1 else 0 else generatedInk / referenceInk
    passed =
      meanError <= maximumMeanError
        && withinRatio >= minimumPixelsWithinTolerance
        && inkRatio >= minimumInkRatio
        && inkRatio <= maximumInkRatio

imageInk :: Image PixelRGB8 -> Double
imageInk = fromIntegral . Vector.foldl' (\total channel -> total + (255 - fromIntegral channel :: Integer)) 0 . imageData

countPixelsWithin :: Image PixelRGB8 -> Image PixelRGB8 -> Int -> Int
countPixelsWithin reference generated pixelCount = go 0 0
  where
    left = imageData reference
    right = imageData generated
    go pixel matched
      | pixel == pixelCount = matched
      | otherwise =
          let offset = pixel * 3
              maximumDifference = maximum [channelDifference left right offset, channelDifference left right (offset + 1), channelDifference left right (offset + 2)]
           in go (pixel + 1) (if maximumDifference <= pixelTolerance then matched + 1 else matched)

channelDifference :: Vector.Vector Word8 -> Vector.Vector Word8 -> Int -> Int
channelDifference left right index = abs (fromIntegral (left Vector.! index) - fromIntegral (right Vector.! index) :: Int)

differenceImage :: Image PixelRGB8 -> Image PixelRGB8 -> Image PixelRGB8
differenceImage reference generated =
  generateImage pixel (imageWidth reference) (imageHeight reference)
  where
    left = imageData reference
    right = imageData generated
    pixel x y =
      let offset = (y * imageWidth reference + x) * 3
       in PixelRGB8
            (differenceChannel left right offset)
            (differenceChannel left right (offset + 1))
            (differenceChannel left right (offset + 2))

differenceChannel :: Vector.Vector Word8 -> Vector.Vector Word8 -> Int -> Word8
differenceChannel left right index = fromIntegral (min 255 (channelDifference left right index * 4))

dimensions :: Image pixel -> (Int, Int)
dimensions image = (imageWidth image, imageHeight image)

writeReports :: FilePath -> [ScaleEvaluation] -> EvaluationResult -> IO ()
writeReports directory scales result = do
  LazyByteString.writeFile (directory </> "evaluation.json") json
  Text.writeFile (directory </> "report.html") html
  where
    json =
      encode
        ( object
            [ "meanError" .= evaluationMeanError result
            , "pixelsWithinTolerance" .= evaluationPixelsWithinTolerance result
            , "inkRatio" .= evaluationInkRatio result
            , "maximumMeanError" .= maximumMeanError
            , "minimumPixelsWithinTolerance" .= minimumPixelsWithinTolerance
            , "minimumInkRatio" .= minimumInkRatio
            , "maximumInkRatio" .= maximumInkRatio
            , "pixelTolerance" .= pixelTolerance
            , "passed" .= evaluationPassed result
            , "scales" .= map scaleJson scales
            ]
        )
    html =
      Text.unlines
        [ "<!doctype html><html><body><h1>Parser evaluation</h1>"
        , "<p>Mean normalized channel error: " <> Text.pack (show (evaluationMeanError result)) <> "</p>"
        , "<p>Pixels within tolerance: " <> Text.pack (show (evaluationPixelsWithinTolerance result)) <> "</p>"
        , "<p>Generated/reference ink ratio: " <> Text.pack (show (evaluationInkRatio result)) <> "</p>"
        , "<p>Passed: " <> Text.pack (show (evaluationPassed result)) <> "</p>"
        , foldMap scaleHtml scales
        , "</body></html>"
        ]
    scaleJson (ScaleEvaluation dpi scale) =
      object
        [ "dpi" .= dpi
        , "meanError" .= evaluationMeanError scale
        , "pixelsWithinTolerance" .= evaluationPixelsWithinTolerance scale
        , "inkRatio" .= evaluationInkRatio scale
        , "passed" .= evaluationPassed scale
        ]
    scaleHtml (ScaleEvaluation dpi scale) =
      Text.unlines
        [ "<h2>" <> Text.pack (show dpi) <> " DPI</h2>"
        , "<p>Mean error: " <> Text.pack (show (evaluationMeanError scale)) <> "; pixels within tolerance: " <> Text.pack (show (evaluationPixelsWithinTolerance scale)) <> "; ink ratio: " <> Text.pack (show (evaluationInkRatio scale)) <> "</p>"
        , "<img src=\"reference-" <> Text.pack (show dpi) <> ".png\" width=\"32%\" alt=\"Reference at " <> Text.pack (show dpi) <> " DPI\">"
        , "<img src=\"generated-" <> Text.pack (show dpi) <> ".png\" width=\"32%\" alt=\"Generated at " <> Text.pack (show dpi) <> " DPI\">"
        , "<img src=\"difference-" <> Text.pack (show dpi) <> ".png\" width=\"32%\" alt=\"Difference at " <> Text.pack (show dpi) <> " DPI\">"
        ]
