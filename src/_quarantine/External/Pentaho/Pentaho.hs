module External.Pentaho.Pentaho
  ( PentahoConfig   (..),
    generateReport
  ) where

import Data.Text (Text)
import qualified Data.Text as T

data PentahoConfig = PentahoConfig {serverUrl :: String}

generateReport :: PentahoConfig -> Text -> IO (Either Text FilePath)
generateReport _ _ = do
  -- Placeholder: would call Pentaho server or API to generate report
  pure $ Right "/reports/pentaho/generated_report.prpt"
