{-# LANGUAGE DataKinds #-}
{-# LANGUAGE OverloadedStrings #-}

-- | The software factory's imperative shell.
--
-- This is the only module that decides which files to read and write. The
-- parser, interpreter, and validator receive explicit values, so tests can
-- run them without hidden filesystem access.
module Factory.Pipeline
  ( discoverSinglePdf
  , outputCompanionPaths
  , runCommand
  , validateOutputPath
  ) where

import Control.Exception (IOException, throwIO, try)
import Control.Monad (forM, when)
import Data.List (sort)
import Data.Text (Text)
import Factory.Domain
import Factory.Evaluation (EvaluationResult (..), runVisualEvaluation)
import Factory.Pdf (PdfSummary (..), parsePdf)
import Factory.Site (validateScene, writeSite)
import System.Directory
  ( canonicalizePath
  , createDirectoryIfMissing
  , doesDirectoryExist
  , doesFileExist
  , doesPathExist
  , listDirectory
  , makeAbsolute
  , pathIsSymbolicLink
  , removePathForcibly
  , renameDirectory
  )
import System.Environment (getArgs)
import System.Exit (exitFailure)
import System.FilePath (dropTrailingPathSeparator, isAbsolute, makeRelative, normalise, splitDirectories, takeDirectory, takeExtension, takeFileName, (</>))
import qualified Data.Text as Text
import qualified Data.Text.IO as Text

runCommand :: IO ()
runCommand = do
  arguments <- getArgs
  result <- case arguments of
    ["inspect", repositoryRoot] -> inspectRepository repositoryRoot
    ["build", repositoryRoot, outputDirectory] -> buildRepository repositoryRoot outputDirectory
    ["evaluate", repositoryRoot, outputDirectory] -> evaluateRepository repositoryRoot outputDirectory
    _ -> pure (Left (IoError "usage: freeform-site inspect ROOT | build ROOT DIST | evaluate ROOT DIST"))
  case result of
    Left buildError -> Text.putStrLn ("ERROR: " <> renderError buildError) >> exitFailure
    Right message -> Text.putStrLn message

discoverSinglePdf :: FilePath -> IO (Either BuildError FilePath)
discoverSinglePdf repositoryRoot = do
  result <- try (collectPdfs repositoryRoot)
  pure $ case result of
    Left exception -> Left (IoError (Text.pack (show (exception :: IOException))))
    Right [pdf] -> Right pdf
    Right pdfs -> Left (PdfCountError (length pdfs))

inspectRepository :: FilePath -> IO (Either BuildError Text)
inspectRepository repositoryRoot = do
  absoluteRoot <- makeAbsolute repositoryRoot
  withSinglePdf absoluteRoot $ \pdf -> do
    let scratch = absoluteRoot </> "build" </> "inspect-assets"
    resetDirectory scratch
    parsed <- parsePdf pdf scratch
    removePathForcibly scratch
    pure $ do
      (_, summary) <- parsed
      Right (summaryText pdf summary)

buildRepository :: FilePath -> FilePath -> IO (Either BuildError Text)
buildRepository repositoryRoot outputDirectory = do
  absoluteRoot <- canonicalizePath repositoryRoot
  prepared <- prepareOutputDirectories outputDirectory
  case prepared of
    Left buildError -> pure (Left buildError)
    Right (absoluteOutput, stagingDirectory, backupDirectory) ->
      case traverse (validateOutputPath absoluteRoot) [absoluteOutput, stagingDirectory, backupDirectory] of
        Left buildError -> pure (Left buildError)
        Right _ -> buildToStaging absoluteRoot absoluteOutput stagingDirectory backupDirectory

buildToStaging :: FilePath -> FilePath -> FilePath -> FilePath -> IO (Either BuildError Text)
buildToStaging absoluteRoot absoluteOutput stagingDirectory backupDirectory =
  withSinglePdf absoluteRoot $ \pdf -> do
    resetDirectory stagingDirectory
    parsed <- parsePdf pdf (stagingDirectory </> "assets")
    case parsed of
      Left buildError -> removePathForcibly stagingDirectory >> pure (Left buildError)
      Right (rawScene, summary) -> case validateScene rawScene of
        Left buildError -> removePathForcibly stagingDirectory >> pure (Left buildError)
        Right scene -> do
          writeSite (absoluteRoot </> "site") stagingDirectory scene
          promoted <- promoteDirectory stagingDirectory absoluteOutput backupDirectory
          pure $ case promoted of
            Left buildError -> Left buildError
            Right () -> Right ("Built JavaScript scene from " <> Text.pack (takeFileName pdf) <> "\n" <> summaryText pdf summary)

evaluateRepository :: FilePath -> FilePath -> IO (Either BuildError Text)
evaluateRepository repositoryRoot outputDirectory = do
  built <- buildRepository repositoryRoot outputDirectory
  case built of
    Left buildError -> pure (Left buildError)
    Right _ -> do
      discovered <- discoverSinglePdf repositoryRoot
      case discovered of
        Left buildError -> pure (Left buildError)
        Right pdf -> do
          let reportDirectory = repositoryRoot </> "build" </> "evaluation"
          evaluation <- runVisualEvaluation pdf outputDirectory reportDirectory
          pure $ case evaluation of
            Left buildError -> Left buildError
            Right result
              | evaluationPassed result -> Right (evaluationText "Evaluation passed." reportDirectory result)
              | otherwise -> Left (EvaluationError (evaluationText "Evaluation did not meet the required thresholds." reportDirectory result))

withSinglePdf :: FilePath -> (FilePath -> IO (Either BuildError Text)) -> IO (Either BuildError Text)
withSinglePdf root action = discoverSinglePdf root >>= either (pure . Left) action

collectPdfs :: FilePath -> IO [FilePath]
collectPdfs directory = do
  entries <- sort <$> listDirectory directory
  fmap concat . forM entries $ \entry -> do
    let path = directory </> entry
    isDirectory <- doesDirectoryExist path
    isFile <- doesFileExist path
    isSymbolicLink <- pathIsSymbolicLink path
    if isDirectory && not isSymbolicLink && entry `notElem` ignoredDirectories
      then collectPdfs path
      else pure [path | isFile && not isSymbolicLink && map asciiLower (takeExtension entry) == ".pdf"]

ignoredDirectories :: [FilePath]
ignoredDirectories = [".git", "build", "dist", "dist.building", "dist.previous", "dist-newstyle", "node_modules"]

resetDirectory :: FilePath -> IO ()
resetDirectory directory = do
  exists <- doesPathExist directory
  if exists then removePathForcibly directory else pure ()
  createDirectoryIfMissing True directory

promoteDirectory :: FilePath -> FilePath -> FilePath -> IO (Either BuildError ())
promoteDirectory stagingDirectory outputDirectory backupDirectory = do
  result <- tryIo $ do
    recoverInterruptedPromotion outputDirectory backupDirectory
    renameDirectory outputDirectory backupDirectory
    promoted <- tryIo (renameDirectory stagingDirectory outputDirectory)
    case promoted of
      Left exception -> renameDirectory backupDirectory outputDirectory >> throwIO exception
      Right () -> removePathForcibly backupDirectory
  pure $ case result of
    Left exception -> Left (IoError (Text.pack (show exception)))
    Right () -> Right ()

recoverInterruptedPromotion :: FilePath -> FilePath -> IO ()
recoverInterruptedPromotion outputDirectory backupDirectory = do
  outputExists <- doesPathExist outputDirectory
  backupExists <- doesPathExist backupDirectory
  when (backupExists && outputExists) (removePathForcibly backupDirectory)
  when (backupExists && not outputExists) (renameDirectory backupDirectory outputDirectory)
  finalOutputExists <- doesPathExist outputDirectory
  if finalOutputExists then pure () else createDirectoryIfMissing True outputDirectory

prepareOutputDirectories :: FilePath -> IO (Either BuildError (FilePath, FilePath, FilePath))
prepareOutputDirectories outputDirectory = do
  absoluteOutput <- makeAbsolute outputDirectory
  let (outputPath, stagingPath, backupPath) = outputCompanionPaths absoluteOutput
  output <- prepareRemovalPath outputPath
  staging <- prepareRemovalPath stagingPath
  backup <- prepareRemovalPath backupPath
  pure ((,,) <$> output <*> staging <*> backup)

outputCompanionPaths :: FilePath -> (FilePath, FilePath, FilePath)
outputCompanionPaths outputDirectory =
  (normalized, normalized <> ".building", normalized <> ".previous")
  where
    normalized = dropTrailingPathSeparator (normalise outputDirectory)

prepareRemovalPath :: FilePath -> IO (Either BuildError FilePath)
prepareRemovalPath path = do
  let absolutePath = normalise path
  exists <- doesPathExist absolutePath
  isSymbolicLink <- if exists then pathIsSymbolicLink absolutePath else pure False
  if isSymbolicLink
    then pure (Left (IoError "DIST, its staging path, and its backup path must not be symbolic links"))
    else do
      canonicalParent <- canonicalizeExistingAncestors (takeDirectory absolutePath)
      pure (Right (canonicalParent </> takeFileName absolutePath))

canonicalizeExistingAncestors :: FilePath -> IO FilePath
canonicalizeExistingAncestors path = do
  exists <- doesPathExist path
  if exists
    then canonicalizePath path
    else do
      parent <- canonicalizeExistingAncestors (takeDirectory path)
      pure (parent </> takeFileName path)

tryIo :: IO value -> IO (Either IOException value)
tryIo = try

-- | Reject output locations whose removal would also remove the repository.
validateOutputPath :: FilePath -> FilePath -> Either BuildError ()
validateOutputPath repositoryRoot outputDirectory
  | outputContainsRoot = Left (IoError "DIST must not equal or contain the repository root")
  | otherwise = Right ()
  where
    relativeRoot = makeRelative (normalise outputDirectory) (normalise repositoryRoot)
    outputContainsRoot = relativeRoot == "." || isDescendant relativeRoot
    isDescendant path =
      not (isAbsolute path)
        && case splitDirectories path of
          ".." : _ -> False
          _ -> True

summaryText :: FilePath -> PdfSummary -> Text
summaryText pdf summary =
  Text.unlines
    [ "File: " <> Text.pack (takeFileName pdf)
    , "Pages: " <> numberText (summaryPageCount summary)
    , "Board: " <> decimalText (summaryWidth summary) <> " x " <> decimalText (summaryHeight summary) <> " pt"
    , "Operators: " <> numberText (summaryOperatorCount summary)
    , "Images: " <> numberText (summaryImageCount summary)
    , "Vector artworks: " <> numberText (summaryVectorCount summary)
    , "Raster images: " <> numberText (summaryRasterCount summary)
    , "Links: " <> numberText (summaryLinkCount summary)
    ]

renderError :: BuildError -> Text
renderError buildError = case buildError of
  PdfCountError count -> "expected exactly one PDF file, found " <> numberText count
  PageCountError count -> "PDF must contain exactly one page, found " <> numberText count
  PdfStructureError message -> "invalid PDF structure: " <> message
  UnsupportedOperator message -> "unsupported PDF operator: " <> message
  UnsupportedImage message -> "unsupported PDF image: " <> message
  GraphicsStateError message -> "invalid PDF graphics state: " <> message
  InvalidScene message -> "invalid generated scene: " <> message
  InvalidUrl message -> "invalid PDF link: " <> message
  EvaluationError message -> "evaluation failed: " <> message
  IoError message -> message

numberText :: Show value => value -> Text
numberText = Text.pack . show

decimalText :: Double -> Text
decimalText = Text.pack . show

asciiLower :: Char -> Char
asciiLower character
  | 'A' <= character && character <= 'Z' = toEnum (fromEnum character + 32)
  | otherwise = character

evaluationText :: Text -> FilePath -> EvaluationResult -> Text
evaluationText statusMessage reportDirectory result =
  Text.unlines
    [ statusMessage
    , "Mean normalized channel error: " <> decimalText (evaluationMeanError result)
    , "Pixels within tolerance: " <> decimalText (evaluationPixelsWithinTolerance result)
    , "Generated/reference ink ratio: " <> decimalText (evaluationInkRatio result)
    , "Evidence: " <> Text.pack (reportDirectory </> "report.html")
    ]
