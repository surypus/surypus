module Test.MakeTest where

import App (mkApp)
import Network.Wai (Application)

-- | Unified entry point for creating a test application instance
makeApp :: IO Application
makeApp = mkApp
