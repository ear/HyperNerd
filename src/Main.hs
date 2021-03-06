{-# LANGUAGE OverloadedStrings #-}
module Main where

import           Bot
import           BotState
import           Control.Concurrent
import           Control.Concurrent.STM
import           Control.Monad
import qualified Database.SQLite.Simple as SQLite
import           IrcTransport
import qualified Sqlite.EntityPersistence as SEP
import           System.Clock
import           System.Environment

ircTransport :: Bot -> BotState -> IO ()
ircTransport b botState =
    join
      (eventLoop b
          <$> getTime Monotonic
          <*> SQLite.withTransaction (bsSqliteConn botState)
                (applyEffect botState $ b Join))

eventLoop :: Bot -> TimeSpec -> BotState -> IO ()
eventLoop b prevCPUTime botState =
    do threadDelay 10000        -- to prevent busy looping
       currCPUTime <- getTime Monotonic
       let deltaTime = toNanoSecs (currCPUTime - prevCPUTime) `div` 1000000
       mb <- atomically $ tryReadTQueue (bsIncoming botState)
       maybe (return botState)
             (handleIrcMessage b botState)
             mb
         >>= advanceTimeouts deltaTime
         >>= eventLoop b currCPUTime

logicEntry :: IncomingQueue -> OutcomingQueue -> Config -> String -> IO ()
logicEntry incoming outcoming conf databasePath =
    SQLite.withConnection databasePath
      $ \sqliteConn -> do SEP.prepareSchema sqliteConn
                          ircTransport bot
                             BotState { bsConfig = conf
                                      , bsSqliteConn = sqliteConn
                                      , bsTimeouts = []
                                      , bsIncoming = incoming
                                      , bsOutcoming = outcoming
                                      }

mainWithArgs :: [String] -> IO ()
mainWithArgs [configPath, databasePath] =
    do incoming <- atomically newTQueue
       outcoming <- atomically newTQueue
       conf <- configFromFile configPath
       _ <- forkIO $ ircTransportEntry incoming outcoming configPath
       logicEntry incoming outcoming conf databasePath
mainWithArgs _ = error "./HyperNerd <config-file> <database-file>"

main :: IO ()
main = getArgs >>= mainWithArgs
