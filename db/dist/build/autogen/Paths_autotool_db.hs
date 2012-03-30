module Paths_autotool_db (
    version,
    getBinDir, getLibDir, getDataDir, getLibexecDir,
    getDataFileName
  ) where

import qualified Control.Exception as Exception
import Data.Version (Version(..))
import System.Environment (getEnv)
catchIO :: IO a -> (Exception.IOException -> IO a) -> IO a
catchIO = Exception.catch


version :: Version
version = Version {versionBranch = [1,0], versionTags = []}
bindir, libdir, datadir, libexecdir :: FilePath

bindir     = "/usr/local/bin"
libdir     = "/usr/local/lib/autotool-db-1.0/ghc-7.4.1"
datadir    = "/usr/local/share/autotool-db-1.0"
libexecdir = "/usr/local/libexec"

getBinDir, getLibDir, getDataDir, getLibexecDir :: IO FilePath
getBinDir = catchIO (getEnv "autotool_db_bindir") (\_ -> return bindir)
getLibDir = catchIO (getEnv "autotool_db_libdir") (\_ -> return libdir)
getDataDir = catchIO (getEnv "autotool_db_datadir") (\_ -> return datadir)
getLibexecDir = catchIO (getEnv "autotool_db_libexecdir") (\_ -> return libexecdir)

getDataFileName :: FilePath -> IO FilePath
getDataFileName name = do
  dir <- getDataDir
  return (dir ++ "/" ++ name)
