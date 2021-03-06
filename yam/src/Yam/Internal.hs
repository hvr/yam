{-# LANGUAGE AllowAmbiguousTypes #-}
{-# LANGUAGE NoPolyKinds         #-}
module Yam.Internal(
  -- * Application Functions
    startYam
  , start
  ) where

import qualified Data.ByteString.Lazy.Char8         as B
import qualified Data.Vault.Lazy                    as L
import           Network.Wai.Handler.Warp
import           Servant
import           Servant.Server.Internal.ServantErr
import           Servant.Swagger
import           Yam.Logger
import           Yam.Middleware
import           Yam.Middleware.Trace
import           Yam.Swagger
import           Yam.Types

whenException :: SomeException -> Response
whenException e = responseServantErr $ fromMaybe err400 { errBody = B.pack $ show e } (fromException e :: Maybe ServantErr)

startYam
  :: forall api. (HasSwagger api, HasServer api '[Env])
  => AppConfig
  -> SwaggerConfig
  -> LogConfig
  -> TraceConfig
  -> Version
  -> [AppMiddleware]
  -> Proxy api
  -> ServerT api App
  -> IO ()
startYam ac@AppConfig{..} sw@SwaggerConfig{..} logConfig traceConfig vs middlewares proxy server
  = withLogger name logConfig $ do
      logInfo $ "Start Service [" <> name <> "] ..."
      logger <- askLoggerIO
      let act = runAM $ foldr1 (<>) (traceMiddleware traceConfig : middlewares)
      act (putLogger logger $ Env L.empty Nothing ac) $ \(env, middleware) -> do
        let cxt                  = env :. EmptyContext
            pCxt                 = Proxy :: Proxy '[Env]
            portText             = showText port
            proxy'               = Proxy :: Proxy (Vault :> api)
            server'              = runRequest proxy pCxt server
            settings             = defaultSettings
                                 & setPort port
                                 & setOnException (\_ _ -> return ())
                                 & setOnExceptionResponse whenException
        when enabled $
          logInfo $ "Swagger enabled: http://localhost:" <> portText <> "/" <> pack urlDir
        logInfo $ "Servant started on port(s): " <> portText
        lift $ runSettings settings
          $ middleware
          $ serveWithContextAndSwagger sw ac vs proxy' cxt
          $ hoistServerWithContext proxy' pCxt (transApp env) server'

runRequest :: (HasServer api context) => Proxy api -> Proxy context -> ServerT api App -> Vault -> ServerT api App
runRequest p pc a v = hoistServerWithContext p pc go a
  where
    {-# INLINE go #-}
    go :: App a -> App a
    go = local (\env -> env { reqAttributes = Just v})

transApp :: Env -> App a -> Handler a
transApp b c = liftIO $ runApp b c

start
  :: forall api. (HasSwagger api, HasServer api '[Env])
  => Properties
  -> Version
  -> [AppMiddleware]
  -> Proxy api
  -> ServerT api App
  -> IO ()
start p = startYam
  (readConfig "yam.application" p)
  (readConfig "yam.swagger"     p)
  (readConfig "yam.logging"     p)
  (readConfig "yam.trace"       p)
