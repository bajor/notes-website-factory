{-# LANGUAGE OverloadedStrings #-}

-- | Produce evidence for the software-factory feedback loop.
--
-- The deployed page never uses a rendered PDF. During development, however,
-- a mature renderer is a useful oracle. We compare that oracle with a browser
-- screenshot of our generated DOM/SVG scene and keep the difference image
-- as evidence for the next parser iteration.
module Factory.Evaluation
  ( CaptureTile (..)
  , EvaluationResult (..)
  , calculateDifference
  , captureTiles
  , runVisualEvaluation
  , stitchTiles
  ) where

import Codec.Picture
  ( DynamicImage
  , Image (..)
  , PixelRGB8 (PixelRGB8)
  , convertRGB8
  , generateImage
  , readImage
  , writePng
  )
import Control.Exception (IOException, try)
import Control.Monad (forM_)
import Control.Monad.Primitive (PrimMonad, PrimState)
import Control.Monad.ST (runST)
import Data.Aeson (encode, object, (.=))
import Data.Text (Text)
import Data.Word (Word8)
import Factory.Domain (BuildError (EvaluationError))
import System.Directory (createDirectoryIfMissing, doesPathExist, makeAbsolute, removePathForcibly)
import System.Exit (ExitCode (ExitSuccess))
import System.Environment (lookupEnv)
import System.FilePath (takeDirectory, takeFileName, (</>))
import System.IO (IOMode (ReadMode), withBinaryFile)
import System.Process (readProcessWithExitCode)
import qualified Data.ByteString as ByteString
import qualified Data.ByteString.Lazy as LazyByteString
import qualified Data.Text as Text
import qualified Data.Text.IO as Text
import qualified Data.Vector.Storable as Vector
import qualified Data.Vector.Storable.Mutable as MutableVector

data CaptureTile = CaptureTile
  { captureX :: Int
  , captureY :: Int
  , captureWidth :: Int
  , captureHeight :: Int
  }
  deriving stock (Eq, Show)

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

maximumCaptureWidth :: Int
maximumCaptureWidth = 8192

maximumCaptureHeight :: Int
maximumCaptureHeight = 4096

runVisualEvaluation :: FilePath -> FilePath -> FilePath -> IO (Either BuildError EvaluationResult)
runVisualEvaluation pdfPath siteDirectory reportDirectory = do
  reportExists <- doesPathExist reportDirectory
  if reportExists then removePathForcibly reportDirectory else pure ()
  createDirectoryIfMissing True reportDirectory
  absoluteSite <- makeAbsolute siteDirectory
  evaluated <- evaluateScales absoluteSite referenceDpis
  case evaluated of
    Left buildError -> pure (Left buildError)
    Right scales -> do
      let result = aggregateResults scales
      writeReports reportDirectory scales result
      pure (Right result)
  where
    evaluateScales _ [] = pure (Right [])
    evaluateScales absoluteSite (dpi : remaining) = do
      evaluated <- evaluateScale pdfPath absoluteSite reportDirectory dpi
      case evaluated of
        Left buildError -> pure (Left buildError)
        Right scale -> fmap (fmap (scale :)) (evaluateScales absoluteSite remaining)

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
      referenceDimensions <- readPngDimensions referencePath
      case referenceDimensions of
        Left message -> pure (Left (EvaluationError message))
        Right (width, height) -> do
          browserExit <- runBrowser absoluteSite generatedPath dpi width height
          case browserExit of
            Left message -> pure (Left (EvaluationError message))
            Right () -> fmap (ScaleEvaluation dpi) <$> compareImagePaths referencePath generatedPath differencePath

runBrowser :: FilePath -> FilePath -> Int -> Int -> Int -> IO (Either Text ())
runBrowser siteDirectory screenshotPath dpi width height = do
  browser <- maybe "chromium" id <$> lookupEnv "CHROMIUM"
  case captureTiles width height of
    [] -> pure (Left "browser capture dimensions must be positive")
    tiles@(firstTile : _) -> do
      renderedDom <- runToolOutput browser (browserArguments firstTile <> ["--dump-dom", pageUrl firstTile])
      case renderedDom of
        Left message -> pure (Left message)
        Right html
          | not ("data-ready=\"true\"" `Text.isInfixOf` html) -> pure (Left "chromium did not report a completed scene")
          | [tile] <- tiles -> runTool browser (browserArguments tile <> ["--screenshot=" <> screenshotPath, pageUrl tile])
          | otherwise -> captureAndStitch browser tiles
  where
    captureAndStitch browser tiles = do
      createDirectoryIfMissing True tileDirectory
      captured <- captureAll tiles
      result <- case captured of
        Left message -> pure (Left message)
        Right () -> do
          stitched <- stitchTileFiles width height [(tile, tilePath tile) | tile <- tiles]
          case stitched of
            Left message -> pure (Left message)
            Right image -> writePngSafely screenshotPath image
      removePathForcibly tileDirectory
      pure result
      where
        captureAll [] = pure (Right ())
        captureAll (tile : remaining) = do
          result <- captureTile tile
          case result of
            Left message -> pure (Left message)
            Right () -> captureAll remaining
        captureTile tile = runTool browser (browserArguments tile <> ["--screenshot=" <> tilePath tile, pageUrl tile])
    tileDirectory = takeDirectory screenshotPath </> ".capture-tiles"
    tilePath tile = tileDirectory </> takeFileName screenshotPath <> ".tile-" <> show (captureX tile) <> "-" <> show (captureY tile) <> ".png"
    pageUrl tile =
      "file://"
        <> siteDirectory </> "index.html"
        <> "?evaluation=" <> show dpi
        <> "&evaluation-x=" <> show (captureX tile)
        <> "&evaluation-y=" <> show (captureY tile)
    browserArguments tile =
      [ "--headless"
      , "--no-sandbox"
      , "--disable-gpu"
      , "--hide-scrollbars"
      , "--allow-file-access-from-files"
      , "--virtual-time-budget=15000"
      , "--force-device-scale-factor=1"
      , "--window-size=" <> show (captureWidth tile) <> "," <> show (captureHeight tile)
      ]

captureTiles :: Int -> Int -> [CaptureTile]
captureTiles width height
  | width <= 0 || height <= 0 = []
  | otherwise =
      [ CaptureTile x y (min maximumCaptureWidth (width - x)) (min maximumCaptureHeight (height - y))
      | y <- [0, maximumCaptureHeight .. height - 1]
      , x <- [0, maximumCaptureWidth .. width - 1]
      ]

stitchTiles :: Int -> Int -> [(CaptureTile, Image PixelRGB8)] -> Either Text (Image PixelRGB8)
stitchTiles width height captures
  | null expected = Left "stitched image dimensions must be positive"
  | map fst captures /= expected = Left "captured tiles do not match the expected grid"
  | any hasWrongDimensions captures = Left "captured tile dimensions do not match the tile plan"
  | otherwise = Right $ runST $ do
      destination <- MutableVector.new (width * height * 3)
      forM_ captures $ \(tile, image) -> copyTile destination width tile image
      pixels <- Vector.unsafeFreeze destination
      pure (Image width height pixels)
  where
    expected = captureTiles width height
    hasWrongDimensions (tile, image) = dimensions image /= (captureWidth tile, captureHeight tile)

stitchTileFiles :: Int -> Int -> [(CaptureTile, FilePath)] -> IO (Either Text (Image PixelRGB8))
stitchTileFiles width height captures
  | map fst captures /= captureTiles width height = pure (Left "captured tiles do not match the expected grid")
  | otherwise = do
      destination <- MutableVector.new (width * height * 3)
      copied <- copyCaptures destination captures
      case copied of
        Left message -> pure (Left message)
        Right () -> do
          pixels <- Vector.unsafeFreeze destination
          pure (Right (Image width height pixels))
  where
    copyCaptures _ [] = pure (Right ())
    copyCaptures destination ((tile, path) : remaining) = do
      decoded <- readRgb path
      case decoded of
        Left message -> pure (Left message)
        Right image
          | dimensions image /= (captureWidth tile, captureHeight tile) -> pure (Left "captured tile dimensions do not match the tile plan")
          | otherwise -> do
              copyTile destination width tile image
              copyCaptures destination remaining

copyTile :: PrimMonad m => MutableVector.MVector (PrimState m) Word8 -> Int -> CaptureTile -> Image PixelRGB8 -> m ()
copyTile destination outputWidth tile image =
  forM_ [0 .. captureHeight tile - 1] $ \row ->
    Vector.copy
      (MutableVector.slice (destinationOffset row) rowLength destination)
      (Vector.slice (row * rowLength) rowLength (imageData image))
  where
    rowLength = captureWidth tile * 3
    destinationOffset row = ((captureY tile + row) * outputWidth + captureX tile) * 3

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

readPngDimensions :: FilePath -> IO (Either Text (Int, Int))
readPngDimensions path = do
  header <- tryReadHeader path
  pure $ case header of
    Left exception -> Left (Text.pack (path <> " could not be read: " <> show exception))
    Right bytes -> parsePngDimensions bytes

tryReadHeader :: FilePath -> IO (Either IOException ByteString.ByteString)
tryReadHeader path = try (withBinaryFile path ReadMode (`ByteString.hGet` 24))

parsePngDimensions :: ByteString.ByteString -> Either Text (Int, Int)
parsePngDimensions header
  | ByteString.length header /= 24 = Left "PNG header is incomplete"
  | ByteString.take 8 header /= ByteString.pack [137, 80, 78, 71, 13, 10, 26, 10] = Left "image does not have a PNG signature"
  | ByteString.take 8 (ByteString.drop 8 header) /= ByteString.pack [0, 0, 0, 13, 73, 72, 68, 82] = Left "PNG does not start with an IHDR chunk"
  | width <= 0 || height <= 0 = Left "PNG dimensions must be positive"
  | otherwise = Right (width, height)
  where
    width = word32At 16
    height = word32At 20
    word32At offset =
      fromIntegral (ByteString.index header offset) * 16777216
        + fromIntegral (ByteString.index header (offset + 1)) * 65536
        + fromIntegral (ByteString.index header (offset + 2)) * 256
        + fromIntegral (ByteString.index header (offset + 3))

readRgb :: FilePath -> IO (Either Text (Image PixelRGB8))
readRgb path = do
  decoded <- tryReadImage path
  pure $ case decoded of
    Left exception -> Left (Text.pack (path <> " could not be read: " <> show exception))
    Right result -> either (Left . Text.pack) (Right . convertRGB8) result

tryReadImage :: FilePath -> IO (Either IOException (Either String DynamicImage))
tryReadImage = try . readImage

writePngSafely :: FilePath -> Image PixelRGB8 -> IO (Either Text ())
writePngSafely path image = do
  written <- tryWritePng path image
  pure (either (Left . Text.pack . show) Right written)

tryWritePng :: FilePath -> Image PixelRGB8 -> IO (Either IOException ())
tryWritePng path = try . writePng path

compareImagePaths :: FilePath -> FilePath -> FilePath -> IO (Either BuildError EvaluationResult)
compareImagePaths referencePath generatedPath differencePath = do
  reference <- readRgb referencePath
  case reference of
    Left message -> pure (Left (EvaluationError message))
    Right image -> compareImages image generatedPath differencePath

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
