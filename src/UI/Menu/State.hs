{-# LANGUAGE OverloadedStrings #-}

-- | Network state I guess?
module UI.Menu.State ( newStateFromSelectedMenuItem, selectedMenuLine ) where

import qualified Data.Text                     as T

import           Lens.Micro                     ( (^.) )
import qualified Brick.Widgets.List            as BrickList
import           Brick.Widgets.Edit            as E
import           Web.Browser


import           UI.Progress
import           Gopher
import           UI.Types
import           UI.Types.Names
import           UI.Types.Helpers

-- | Get the `MenuLine` which is currently selected, or Nothing.
selectedMenuLine :: Menu -> Maybe MenuLine
selectedMenuLine menu = case l ^. BrickList.listSelectedL of
  Just lineNumber -> Just $ menuLine gopherMenu lineNumber
  Nothing         -> Nothing
  where (Menu (gopherMenu, l, _)) = menu

-- | Make a request based on the currently selected Gopher menu item and change
-- the application state (GopherBrowserState) to reflect the change.
newStateFromSelectedMenuItem :: GopherBrowserState -> IO GopherBrowserState
newStateFromSelectedMenuItem gbs = case lineType of -- FIXME: it's itemType
  (Canonical ct) -> case ct of
    Directory -> initProgressMode gbs Nothing (host, port, resource, MenuMode)
    File -> initProgressMode gbs Nothing (host, port, resource, TextFileMode)
    IndexSearchServer -> pure gbs
      { gbsRenderMode = SearchMode
      , gbsBuffer     = SearchBuffer $ Search
                          { sbQuery             = ""
                          , sbFormerBufferState = gbsBuffer gbs
                          , sbSelector          = resource
                          , sbPort              = port
                          , sbHost              = host
                          , sbEditorState       = E.editor (MyName MyViewport) Nothing ""
                          }
      }
    ImageFile ->
      initProgressMode gbs Nothing (host, port, resource, FileBrowserMode)
    -- FIXME: it's possible this could be an incorrect exception if everything isn't covered, like telnet
    -- so I need to implement those modes above and then of course this can be the catchall...
    _ -> initProgressMode gbs Nothing (host, port, resource, FileBrowserMode)
  (NonCanonical nct) -> case nct of
    HtmlFile -> openBrowser (T.unpack $ T.drop 4 resource) >> pure gbs
    InformationalMessage -> pure gbs
    -- FIXME: same as previous comment...
    _ -> initProgressMode gbs Nothing (host, port, resource, FileBrowserMode)
 where
  menu                             = getMenu gbs
  (host, port, resource, lineType) = case selectedMenuLine menu of
    -- ParsedLine
    Just (Parsed      gl) -> (glHost gl, glPort gl, glSelector gl, glType gl)
    -- FIXME: why even error here?
    -- Unrecognized/unparseable line
    Just (Unparseable _ ) -> error "Can't do anything with unrecognized line."
    Nothing               -> error "Nothing is selected!"


