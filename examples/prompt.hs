import Control.Monad
import Control.Monad.Trans.Resource
import Data.Conduit
import qualified Data.Conduit.List as CL
import qualified Data.Conduit.Binary as CB
import System.IO
import System.Exit
import System.Environment
import qualified Data.ByteString.Char8 as SB

import Data.Conduit.ZMQ3 (zmqSink)
import System.ZMQ3.Monad (makeSocket, runZMQ)
import qualified System.ZMQ3.Monad as ZMQ

main :: IO ()
main = do
    args <- getArgs
    when (length args /= 2) $ do
        hPutStrLn stderr "usage: prompt <address> <username>"
        exitFailure
    let addr = head args
        name = SB.pack $ args !! 1 ++ ": "
    runResourceT $ runZMQ 1 $ do
        s <- makeSocket ZMQ.Pub
        ZMQ.bind s addr
        CB.sourceHandle stdin $= CB.lines =$= CL.map (SB.append name) $$ zmqSink s []
