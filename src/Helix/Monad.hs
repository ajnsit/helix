{-# LANGUAGE OverloadedStrings, TypeFamilies, RankNTypes, DeriveFunctor #-}

{- |
Module      :  Helix.Monad
Copyright   :  (c) Anupam Jain 2013
License     :  MIT (see the file LICENSE)

Maintainer  :  ajnsit@gmail.com
Stability   :  experimental
Portability :  non-portable (uses ghc extensions)

Defines a Routing Monad that provides easy composition of Routes
-}
module Helix.Monad
    ( -- * Route Monad
      RouteM
      -- * Compose Routes
    , DefaultMaster(..)
    , Route(DefaultRoute)
    , handler
    , middleware
    , route
    , catchall
    , defaultAction
      -- * Convert to Wai Application
    , waiApp
    , toWaiApp
    )
    where

import Network.Wai
import Helix.Routes
import Helix.DefaultRoute
import Network.HTTP.Types (status404)

import Util.Free (F(..), liftF)

-- A Router functor can either add a middleware, or resolve to an app itself.
data RouterF x = M Middleware x | D Application deriving Functor

-- Router type
type RouteM = F RouterF

-- | Catch all routes and process them with the supplied application.
-- Note: As expected from the name, no request proceeds past a catchall.
catchall :: Application -> RouteM ()
catchall a = liftF $ D a

-- | Synonym of `catchall`. Kept for backwards compatibility
defaultAction :: Application -> RouteM ()
defaultAction = catchall

-- | Add a middleware to the application
-- Middleware are ordered so the one declared earlier wraps the ones later
middleware :: Middleware -> RouteM ()
middleware m = liftF $ M m ()

-- | Add a helix handler
handler :: HandlerS DefaultMaster DefaultMaster -> RouteM ()
handler h = middleware $ customRouteDispatch dispatcher' DefaultMaster
  where
    dispatcher' env req = runHandler h env (Just $ DefaultRoute $ getRoute req) req
    getRoute req = (pathInfo $ waiReq req, readQueryString $ queryString $ waiReq req)

-- | Add a route to the application.
-- Routes are ordered so the one declared earlier is matched first.
route :: (Routable master master) => master -> RouteM ()
route = middleware . routeDispatch

-- The final "catchall" application, simply returns a 404 response
-- Ideally you should put your own default application
defaultApplication :: Application
defaultApplication _req h = h $ responseLBS status404 [("Content-Type", "text/plain")] "Error : 404 - Document not found"

-- | Convert a RouteM monad into a wai application.
-- Note: We ignore the return type of the monad
waiApp :: RouteM () -> Application
waiApp (F r) = r (const defaultApplication) f
  where
    f (M m r') = m r'
    f (D a) = a

-- | Similar to waiApp but returns the app in an arbitrary monad
-- Kept for backwards compatibility
toWaiApp :: Monad m => RouteM () -> m Application
toWaiApp = return . waiApp
