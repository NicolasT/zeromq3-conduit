import Control.Monad
import Control.Monad.Trans.Resource
import System.IO
import System.Exit
import System.Environment

import Data.Conduit
import qualified Data.Conduit.List as CL
import qualified Data.Conduit.Binary as CB

import qualified Data.ByteString.Char8 as BS

import Data.Conduit.ZMQ3 (zmqSource)
import System.ZMQ3.Monad (makeSocket, runZMQ)
import qualified System.ZMQ3.Monad as ZMQ

main :: IO ()
main = do
    args <- getArgs
    when (length args < 1) $ do
        hPutStrLn stderr "usage: display <address> [<address>, ...]"
        exitFailure
    runResourceT $ runZMQ 1 $ do
        s <- makeSocket ZMQ.Sub
        ZMQ.subscribe s ""
        mapM_ (ZMQ.connect s) args
        zmqSource s $= CL.map (`BS.append` newline) $$ CB.sinkHandle stdout
  where
    newline = BS.pack "\n"
