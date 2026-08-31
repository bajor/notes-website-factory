{-# LANGUAGE OverloadedStrings #-}

-- | Pure highlighter-frame detection and topic metadata construction.
module Factory.Topic
  ( detectTopicFrames
  , sortTopicCandidates
  , topicFromOcr
  ) where

import Codec.Picture (Image, PixelRGBA8 (PixelRGBA8), imageHeight, imageWidth, pixelAt)
import Data.List (sortOn)
import Data.Maybe (mapMaybe)
import Data.Text (Text)
import Data.Word (Word8)
import Factory.Domain
import Factory.Vectorize (ContourPoint (ContourPoint), traceSelectedContours)
import qualified Data.Text as Text

data PixelBounds = PixelBounds
  { pixelLeft :: Int
  , pixelTop :: Int
  , pixelRight :: Int
  , pixelBottom :: Int
  }

minimumVisibleAlpha :: Word8
minimumVisibleAlpha = 48

minimumChroma :: Int
minimumChroma = 28

minimumRectangularity :: Double
minimumRectangularity = 0.9

minimumBorderShare :: Double
minimumBorderShare = 0.08

minimumInteriorShare :: Double
minimumInteriorShare = 0.003

minimumInteriorPixels :: Int
minimumInteriorPixels = 24

detectTopicFrames :: Image PixelRGBA8 -> [TopicFrame]
detectTopicFrames image = mapMaybe (frameFromContour image) (traceSelectedContours isChromatic image)

sortTopicCandidates :: [TopicCandidate] -> [TopicCandidate]
sortTopicCandidates = concatMap (sortOn leftEdge) . groupRows . sortOn topEdge
  where
    topEdge = unCoordinate . rectY . topicCandidateBounds
    leftEdge = unCoordinate . rectX . topicCandidateBounds

groupRows :: [TopicCandidate] -> [[TopicCandidate]]
groupRows [] = []
groupRows (first : rest) = collect [first] (bottomEdge first) rest
  where
    collect row _ [] = [reverse row]
    collect row rowBottom (candidate : candidates)
      | topEdge candidate <= rowBottom = collect (candidate : row) (max rowBottom (bottomEdge candidate)) candidates
      | otherwise = reverse row : collect [candidate] (bottomEdge candidate) candidates
    topEdge = unCoordinate . rectY . topicCandidateBounds
    bottomEdge candidate = topEdge candidate + unCoordinate (rectHeight (topicCandidateBounds candidate))

topicFromOcr :: Int -> TopicCandidate -> Text -> Either BuildError Topic
topicFromOcr index candidate rawLabel = do
  label <- mkTopicLabel normalized
  pure (Topic label (topicCandidateBounds candidate))
  where
    cleaned = Text.unwords (Text.words rawLabel)
    normalized = if Text.null cleaned then "Topic " <> Text.pack (show index) else cleaned

frameFromContour :: Image PixelRGBA8 -> [ContourPoint] -> Maybe TopicFrame
frameFromContour image contour
  | signedArea contour >= 0 = Nothing
  | innerWidth <= 0 || innerHeight <= 0 = Nothing
  | innerWidth < minimumInteriorPixels || innerHeight < minimumInteriorPixels = Nothing
  | fromIntegral innerWidth / fromIntegral (imageWidth image) < minimumInteriorShare = Nothing
  | fromIntegral innerHeight / fromIntegral (imageHeight image) < minimumInteriorShare = Nothing
  | rectangularity contour inner < minimumRectangularity = Nothing
  | minimumThickness / fromIntegral (min innerWidth innerHeight) < minimumBorderShare = Nothing
  | otherwise = Just (TopicFrame (normalizeBounds image outer) (normalizeBounds image inner))
  where
    inner = contourBounds contour
    innerWidth = pixelRight inner - pixelLeft inner
    innerHeight = pixelBottom inner - pixelTop inner
    minimumBorder = minimum (borderThicknesses image inner)
    minimumThickness = fromIntegral minimumBorder
    outer =
      PixelBounds
        (max 0 (pixelLeft inner - minimumBorder))
        (max 0 (pixelTop inner - minimumBorder))
        (min (imageWidth image) (pixelRight inner + minimumBorder))
        (min (imageHeight image) (pixelBottom inner + minimumBorder))

borderThicknesses :: Image PixelRGBA8 -> PixelBounds -> [Int]
borderThicknesses image bounds =
  [ chromaticRun image centerX (pixelTop bounds - 1) 0 (-1)
  , chromaticRun image (pixelRight bounds) centerY 1 0
  , chromaticRun image centerX (pixelBottom bounds) 0 1
  , chromaticRun image (pixelLeft bounds - 1) centerY (-1) 0
  ]
  where
    centerX = (pixelLeft bounds + pixelRight bounds) `div` 2
    centerY = (pixelTop bounds + pixelBottom bounds) `div` 2

chromaticRun :: Image PixelRGBA8 -> Int -> Int -> Int -> Int -> Int
chromaticRun image startX startY stepX stepY = go startX startY 0
  where
    go x y count
      | x < 0 || y < 0 || x >= imageWidth image || y >= imageHeight image = count
      | isChromatic (pixelAt image x y) = go (x + stepX) (y + stepY) (count + 1)
      | otherwise = count

contourBounds :: [ContourPoint] -> PixelBounds
contourBounds (ContourPoint firstX firstY : rest) = foldl extend initial rest
  where
    initial = PixelBounds firstX firstY firstX firstY
    extend bounds (ContourPoint x y) =
      PixelBounds
        (min x (pixelLeft bounds))
        (min y (pixelTop bounds))
        (max x (pixelRight bounds))
        (max y (pixelBottom bounds))
contourBounds [] = PixelBounds 0 0 0 0

rectangularity :: [ContourPoint] -> PixelBounds -> Double
rectangularity contour bounds
  | boundsArea == 0 = 0
  | otherwise = abs (signedArea contour) / boundsArea
  where
    width = pixelRight bounds - pixelLeft bounds
    height = pixelBottom bounds - pixelTop bounds
    boundsArea = fromIntegral (width * height)

signedArea :: [ContourPoint] -> Double
signedArea [] = 0
signedArea points = fromIntegral (sum (zipWith cross points (tail points <> [head points]))) / 2
  where
    cross (ContourPoint x1 y1) (ContourPoint x2 y2) = x1 * y2 - x2 * y1

normalizeBounds :: Image PixelRGBA8 -> PixelBounds -> Rect ImageSpace
normalizeBounds image bounds =
  Rect
    (Coordinate (fromIntegral (pixelLeft bounds) / width))
    (Coordinate (fromIntegral (pixelTop bounds) / height))
    (Coordinate (fromIntegral (pixelRight bounds - pixelLeft bounds) / width))
    (Coordinate (fromIntegral (pixelBottom bounds - pixelTop bounds) / height))
  where
    width = fromIntegral (imageWidth image)
    height = fromIntegral (imageHeight image)

isChromatic :: PixelRGBA8 -> Bool
isChromatic (PixelRGBA8 red green blue alpha) =
  alpha >= minimumVisibleAlpha && fromIntegral (maximum channels) - fromIntegral (minimum channels) >= minimumChroma
  where
    channels = [red, green, blue]
