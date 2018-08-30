{-# LANGUAGE OverloadedStrings #-}
module Bot.Periodic ( addPeriodicMessage
                    , startPeriodicMessages
                    ) where

import qualified Data.Map as M
import           Data.Maybe
import qualified Data.Text as T
import           Data.Time
import           Effect
import           Entity
import           Events
import           Property

data PeriodicMessage = PeriodicMessage { pmText :: T.Text
                                       , pmAuthor :: T.Text
                                       , pmCreatedAt :: UTCTime
                                       }

instance IsEntity PeriodicMessage where
    toProperties pm =
        M.fromList [ ("text", PropertyText $ pmText pm)
                   , ("author", PropertyText $ pmAuthor pm)
                   , ("createdAt", PropertyUTCTime $ pmCreatedAt pm)
                   ]
    fromProperties properties = do
        text      <- extractProperty "text" properties
        author    <- extractProperty "author" properties
        createdAt <- extractProperty "createdAt" properties
        return PeriodicMessage { pmText = text
                               , pmAuthor = author
                               , pmCreatedAt = createdAt
                               }

addPeriodicMessage :: Sender -> T.Text -> Effect ()
addPeriodicMessage sender message =
    do createAt <- now
       _ <- createEntity "PeriodicMessage" PeriodicMessage { pmText = message
                                                           , pmAuthor = senderName sender
                                                           , pmCreatedAt = createAt
                                                           }
       return ()

startPeriodicMessages :: Effect ()
startPeriodicMessages =
    do maybeEntity <- listToMaybe <$> selectEntities "PeriodicMessage" (Take 1 $ Shuffle All)
       maybePm <- return (maybeEntity >>= fromEntityProperties)
       maybe (return ())
             (say . pmText . entityPayload)
             maybePm
       timeout (20 * 60 * 1000) startPeriodicMessages
