{-# LANGUAGE TypeFamilies, QuasiQuotes, TemplateHaskell, MultiParamTypeClasses #-}
{-# LANGUAGE OverloadedStrings #-}
module Main where
{-
  Example using shakespearean templates (hamlet, cassius, lucius, julius)
-}

import Helix
import Data.Text (Text)
import qualified Data.Text.Lazy as TL
import Network.Wai.Handler.Warp (run)

import Text.Hamlet (hamletFile, hamlet, HtmlUrl)
import Text.Blaze.Html.Renderer.Text (renderHtml)
import Text.Cassius (renderCss, cassius, CssUrl)

import Data.Text.Encoding (encodeUtf8)

-- Data for a person
data Person = Person
  { name :: Text
  , age :: Int
  }

-- Our master datatype
data MyApp = MyApp [Person]

-- The 'Route' type represents the type of the typesafe Routes generated by helix
-- 'Route MyApp' means the 'Route' type generated for the master datatype 'MyApp'
-- We alias it to 'MyAppRoute' for convenience
type MyAppRoute = Route MyApp

-- Initial DB
defaultDB :: MyApp
defaultDB = MyApp [Person "Bob" 12, Person "Mike" 11]

-- Generate routes
mkRoute "MyApp" [parseRoutes|
/ HomeR GET
/style.css StylesheetR GET
|]

getHomeR :: Handler MyApp
getHomeR = runHandlerM $ do
  MyApp people <- sub
  showRouteQuery <- showRouteQuerySub
  let pageTitle = "Hello Hamlet"
  html $ TL.toStrict $ renderHtml $ home pageTitle people showRouteQuery

getStylesheetR :: Handler MyApp
getStylesheetR = runHandlerM $ do
  showRouteQuery <- showRouteQuerySub
  css $ TL.toStrict $ renderCss $ style showRouteQuery

-- Inline cassius example, julius and lucius would be similar
style :: CssUrl MyAppRoute
style = [cassius|
.page-title
  border: 1px solid red
  background: gray
  color: blue
|]

-- External hamlet example
home :: Text -> [Person] -> HtmlUrl MyAppRoute
home pageTitle people = $(hamletFile "templates/home.hamlet")

-- Inline hamlet example
copyright :: HtmlUrl MyAppRoute
copyright = [hamlet| <small>Copyright 2015. All Rights Reserved |]

-- Define Application using RouteM Monad
application :: RouteM ()
application = do
  middleware logStdoutDev
  route defaultDB
  catchall $ staticApp $ defaultFileServerSettings "static"

-- Run the application
main :: IO ()
main = do
  putStrLn "Starting server on port 8080"
  run 8080 (waiApp application)
