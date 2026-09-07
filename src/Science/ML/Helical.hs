module Science.ML.Helical
  ( HelicalConfig   (..),
    generateReport
  ) where

import Data.Text (Text)

data HelicalConfig = HelicalConfig {endpoint :: String}

generateReport :: HelicalConfig -> Text -> IO (Either Text FilePath)
generateReport _ _ = do
  -- Placeholder: would interact with Helical Insight / API
  pure $ Right "/reports/helical/generated_report.hll"
