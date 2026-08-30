{-# LANGUAGE OverloadedStrings #-}

-- | Effectful, bounded OCR for detected topic frames.
module Factory.Ocr
  ( cropArguments
  , detectTopicCandidates
  , recognizeTopics
  ) where

import Codec.Picture (convertRGBA8, readImage)
import Control.Exception (IOException, displayException, try)
import Control.Monad (forM)
import Control.Monad.Except (ExceptT, liftEither, runExceptT, throwError)
import Control.Monad.IO.Class (liftIO)
import Data.Text (Text)
import Factory.Domain
import Factory.Topic (detectTopicFrames, sortTopicCandidates, topicFromOcr)
import System.Directory (createDirectoryIfMissing, doesPathExist, removePathForcibly)
import System.Exit (ExitCode (ExitSuccess))
import System.FilePath ((</>))
import System.Process (readProcessWithExitCode)
import System.Timeout (timeout)
import qualified Data.Text as Text

topicDpi :: Int
topicDpi = 216

detectionDpi :: Int
detectionDpi = 36

toolTimeoutMicroseconds :: Int
toolTimeoutMicroseconds = 120 * 1000000

detectTopicCandidates :: FilePath -> FilePath -> Coordinate BoardSpace -> Coordinate BoardSpace -> IO (Either BuildError [TopicCandidate])
detectTopicCandidates pdfPath scratchDirectory boardWidth boardHeight = do
  prepared <- tryIo (resetDirectory scratchDirectory)
  case prepared of
    Left exception -> pure (Left (ocrException exception))
    Right () -> do
      detected <- tryIo (runExceptT detect)
      cleaned <- tryIo (removePathForcibly scratchDirectory)
      pure $ case (detected, cleaned) of
        (Left exception, _) -> Left (ocrException exception)
        (Right _, Left exception) -> Left (ocrException exception)
        (Right result, Right ()) -> result
  where
    detectionStem = scratchDirectory </> "topic-detection"
    detectionPath = detectionStem <> ".png"
    detect = do
      runTool "pdftoppm" ["-f", "1", "-l", "1", "-singlefile", "-png", "-r", show detectionDpi, pdfPath, detectionStem]
      decoded <- liftIO (readImage detectionPath)
      image <- either (throwError . OcrError . Text.pack) (pure . convertRGBA8) decoded
      pure (map (placeFrame boardWidth boardHeight) (detectTopicFrames image))

recognizeTopics :: FilePath -> FilePath -> [TopicCandidate] -> IO (Either BuildError [Topic])
recognizeTopics pdfPath scratchDirectory candidates = do
  prepared <- tryIo (resetDirectory scratchDirectory)
  case prepared of
    Left exception -> pure (Left (ocrException exception))
    Right () -> do
      recognized <- tryIo (runExceptT (recognizeAll pdfPath scratchDirectory (sortTopicCandidates candidates)))
      cleaned <- tryIo (removePathForcibly scratchDirectory)
      pure $ case (recognized, cleaned) of
        (Left exception, _) -> Left (ocrException exception)
        (Right _, Left exception) -> Left (ocrException exception)
        (Right result, Right ()) -> result

recognizeAll :: FilePath -> FilePath -> [TopicCandidate] -> ExceptT BuildError IO [Topic]
recognizeAll pdfPath scratchDirectory candidates =
  forM (zip [1 ..] candidates) $ \(index, candidate) -> do
    let stem = scratchDirectory </> "topic-" <> show index
        cropPath = stem <> ".png"
    runTool "pdftoppm" (cropArguments pdfPath stem (topicCandidateCrop candidate))
    output <- runToolOutput "tesseract" [cropPath, "stdout", "-l", "eng", "--psm", "7"]
    liftEither (topicFromOcr index candidate output)

placeFrame :: Coordinate BoardSpace -> Coordinate BoardSpace -> TopicFrame -> TopicCandidate
placeFrame boardWidth boardHeight frame =
  TopicCandidate
    { topicCandidateBounds = placeRectangle boardWidth boardHeight (topicFrameOuter frame)
    , topicCandidateCrop = placeRectangle boardWidth boardHeight (topicFrameInner frame)
    }

placeRectangle :: Coordinate BoardSpace -> Coordinate BoardSpace -> Rect ImageSpace -> Rect BoardSpace
placeRectangle boardWidth boardHeight rectangle =
  Rect
    (Coordinate (unCoordinate (rectX rectangle) * unCoordinate boardWidth))
    (Coordinate (unCoordinate (rectY rectangle) * unCoordinate boardHeight))
    (Coordinate (unCoordinate (rectWidth rectangle) * unCoordinate boardWidth))
    (Coordinate (unCoordinate (rectHeight rectangle) * unCoordinate boardHeight))

cropArguments :: FilePath -> FilePath -> Rect BoardSpace -> [String]
cropArguments pdfPath outputStem rectangle =
  [ "-f"
  , "1"
  , "-l"
  , "1"
  , "-singlefile"
  , "-png"
  , "-r"
  , show topicDpi
  , "-x"
  , show left
  , "-y"
  , show top
  , "-W"
  , show (max 1 (right - left))
  , "-H"
  , show (max 1 (bottom - top))
  , pdfPath
  , outputStem
  ]
  where
    scale = fromIntegral topicDpi / 72
    coordinate = unCoordinate
    left, top, right, bottom :: Int
    left = floor (coordinate (rectX rectangle) * scale)
    top = floor (coordinate (rectY rectangle) * scale)
    right = ceiling ((coordinate (rectX rectangle) + coordinate (rectWidth rectangle)) * scale)
    bottom = ceiling ((coordinate (rectY rectangle) + coordinate (rectHeight rectangle)) * scale)

runTool :: FilePath -> [String] -> ExceptT BuildError IO ()
runTool command arguments = do
  result <- liftIO (timeout toolTimeoutMicroseconds (readProcessWithExitCode command arguments ""))
  case result of
    Nothing -> throwError (OcrError (Text.pack (command <> " timed out")))
    Just (ExitSuccess, _, _) -> pure ()
    Just (_, _, standardError) -> throwError (OcrError (toolFailure command standardError))

runToolOutput :: FilePath -> [String] -> ExceptT BuildError IO Text
runToolOutput command arguments = do
  result <- liftIO (timeout toolTimeoutMicroseconds (readProcessWithExitCode command arguments ""))
  case result of
    Nothing -> throwError (OcrError (Text.pack (command <> " timed out")))
    Just (ExitSuccess, standardOutput, _) -> pure (Text.pack standardOutput)
    Just (_, _, standardError) -> throwError (OcrError (toolFailure command standardError))

toolFailure :: FilePath -> String -> Text
toolFailure command standardError = Text.pack (command <> " failed: " <> standardError)

resetDirectory :: FilePath -> IO ()
resetDirectory directory = do
  exists <- doesPathExist directory
  if exists then removePathForcibly directory else pure ()
  createDirectoryIfMissing True directory

tryIo :: IO value -> IO (Either IOException value)
tryIo = try

ocrException :: IOException -> BuildError
ocrException = OcrError . Text.pack . displayException
