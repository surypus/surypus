module External.Jasper.Jasper
  ( JasperConfig   (..),
    generateReport
  ) where

import Data.Text (Text)
import qualified Data.Text as T

data JasperConfig = JasperConfig
  { jcJarPath :: FilePath
  }

-- | Generate a Jasper report (placeholder implementation).
generateReport :: JasperConfig -> Text -> IO (Either Text FilePath)
generateReport _config name = do
  let fname = T.unpack name
  -- In a real setup this would invoke JasperReports CLI/JasperServer with params
  pure $ Right ("/reports/jasper/" ++ fname ++ ".jrprint")
