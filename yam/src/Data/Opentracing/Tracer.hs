module Data.Opentracing.Tracer(
    SpanName
  , newSpan
  , newChildSpan
  , newSpan'
  , forkSpan
  , setReferences
  , setBaggage
  , tag
  , addLog
  , finishSpan
  , MonadTracer(..)
  , MonadTracing(..)
  , newContext
  ) where

import           Control.Monad.IO.Class
import qualified Data.HashMap.Lazy      as HM
import           Data.Opentracing.Types
import           Data.Text              (Text, justifyRight, pack)
import           Data.Time
import           Data.Word
import           Numeric
import           System.Random

type SpanName = Text

class MonadIO m => MonadTracer m where
  askSpanContext :: m SpanContext

class MonadTracer m => MonadTracing m where
  runInSpan :: SpanName -> (Span -> m ()) -> (Span -> m a) ->  m a

{-# INLINE newId #-}
newId :: MonadIO m => m Text
newId = liftIO $ do
  c <- randomIO :: IO Word64
  return $ justifyRight 16 '0' $ pack $ showHex c ""

newSpan :: MonadTracer m => SpanName -> m Span
newSpan name = do
  context     <- askSpanContext
  newSpan' name context []

newSpan' :: MonadTracer m => SpanName -> SpanContext -> [SpanReference] -> m Span
newSpan' name context references = do
  spanId      <- if null references then return (traceId context) else newId
  startTime   <- liftIO getCurrentTime
  let finishTime = Nothing
      tags       = HM.empty
      logs       = HM.empty
  return Span {..}

newChildSpan :: MonadTracer m => SpanName -> Span -> m Span
newChildSpan name parent = newSpan' name (context parent) [SpanReference ChildOf $ spanId parent]

forkSpan :: MonadTracer m => SpanName -> Span -> m Span
forkSpan name parent = newSpan' name (context parent) [SpanReference FollowsFrom $ spanId parent]

setReferences :: Span -> [SpanReference] -> Span
setReferences Span{..} rs = Span{ references = rs, ..}

tag :: Span -> Text -> SpanTag -> Span
tag Span{..} k t = Span{ tags = HM.insert k t tags, ..}

addLog :: Span -> Text -> Text -> Span
addLog Span{..} k t = Span{ logs = HM.insert k t logs, ..}

setBaggage :: Span -> Text -> Maybe Text -> Span
setBaggage Span{..} k t =
  let SpanContext{..} = context
  in Span{ context = SpanContext{ baggage = HM.insert k t baggage ,..}, ..}

finishSpan :: MonadTracer m => Span -> m Span
finishSpan Span{..} = do
  ts <- liftIO getCurrentTime
  return Span {finishTime = Just ts, ..}

newContext :: MonadIO m => m SpanContext
newContext = do
  traceId <- newId
  let baggage = HM.empty
  return SpanContext{..}
