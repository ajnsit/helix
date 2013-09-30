{-# LANGUAGE GeneralizedNewtypeDeriving #-}
{- |
Module      :  Network.Wai.Middleware.Routes.Handler
Copyright   :  (c) Anupam Jain 2013
License     :  MIT (see the file LICENSE)

Maintainer  :  ajnsit@gmail.com
Stability   :  experimental
Portability :  non-portable (uses ghc extensions)

Provides a HandlerM Monad that makes it easy to build Handlers
-}
module Network.Wai.Middleware.Routes.Handler
    ( HandlerM()             -- | A Monad that makes it easier to build a Handler
    , runHandlerM            -- | Run a HandlerM to get a Handler
    , request                -- | Access the request data
    , master                 -- | Access the master datatype
    , next                   -- | Run the next application in the stack
    )
    where

import Data.Conduit (ResourceT)
import Network.Wai (Request, Response)
import Control.Monad.Reader (ReaderT, ask, runReaderT, MonadReader, MonadIO, lift)

import Network.Wai.Middleware.Routes.Routes (RequestData, Handler, waiReq, runNext)

-- | The HandlerM Monad
newtype HandlerM master a = H { extractH :: ReaderT (HandlerState master) (ResourceT IO) a }
    deriving (Monad, MonadIO, Functor, MonadReader (HandlerState master))

-- | The state kept in a HandlerM Monad
data HandlerState master = HandlerState
                { getMaster :: master
                , getRequestData :: RequestData
                }

-- | "Run" HandlerM, resulting in a Handler
runHandlerM :: HandlerM master Response -> Handler master
runHandlerM h m r = runReaderT (extractH h) (HandlerState m r)

-- | Get the master
master :: HandlerM master master
master = ask >>= return . getMaster

-- | Get the request
request :: HandlerM master Request
request = ask >>= return . waiReq . getRequestData

-- | Run the next application
next :: HandlerM master Response
next = ask >>= H . lift . runNext . getRequestData
