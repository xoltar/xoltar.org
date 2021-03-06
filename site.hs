--------------------------------------------------------------------------------
{-# LANGUAGE OverloadedStrings #-}
import           Control.Monad (liftM)
import           Data.Monoid (mappend)
import           System.FilePath
import           Hakyll
import qualified Data.Set as S
import           Text.Pandoc.Options

--------------------------------------------------------------------------------
customPandocCompiler :: Compiler (Item String)
customPandocCompiler =
    let customExtensions = [Ext_definition_lists, Ext_link_attributes]
        defaultExtensions = writerExtensions defaultHakyllWriterOptions
        newExtensions = foldr S.insert defaultExtensions customExtensions
        writerOptions = defaultHakyllWriterOptions {
                          writerExtensions = newExtensions
                        }
    in pandocCompilerWith defaultHakyllReaderOptions writerOptions

main :: IO ()
main = hakyll $ do
    match "favicon.*" $ do
        route   idRoute
        compile copyFileCompiler

    match "images/*" $ do
        route   idRoute
        compile copyFileCompiler

    match "css/*" $ do
        route   idRoute
        compile compressCssCompiler

    match (fromList ["about.rst", "contact.markdown"]) $ do
        route   $ cleanURL
        compile $ pandocCompiler
            >>= loadAndApplyTemplate "templates/default.html" defaultContext
            >>= relativizeUrls

    match "posts/*" $ do
        route $ cleanURL 
        compile $ customPandocCompiler
            -- save immediately after pandoc, but before the templates are applied
            >>= saveSnapshot "content"
            >>= loadAndApplyTemplate "templates/post.html"    postCtx
            >>= loadAndApplyTemplate "templates/default.html" postCtx
            >>= relativizeUrls

    create ["archive.html"] $ do
        route $ cleanURL
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            let archiveCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    constField "title" "Archives"            `mappend`
                    defaultContext

            makeItem ""
                >>= loadAndApplyTemplate "templates/archive.html" archiveCtx
                >>= loadAndApplyTemplate "templates/default.html" archiveCtx
                >>= relativizeUrls


    match "index.html" $ do
        route idRoute
        compile $ do
            posts <- recentFirst =<< loadAll "posts/*"
            teasers <- recentFirst =<< loadAllSnapshots "posts/*" "content"
            let indexCtx =
                    listField "posts" postCtx (return posts) `mappend`
                    listField "teasers" (bodyField "content" `mappend` postCtx) (return teasers) `mappend`
                    constField "title" "Home"                `mappend`
                    defaultContext

            getResourceBody
                >>= applyAsTemplate indexCtx
                >>= loadAndApplyTemplate "templates/default.html" indexCtx
                >>= relativizeUrls

    match "templates/*" $ compile templateCompiler

    create ["atom.xml"] $ do
        route idRoute
        compile $ do
            let feedCtx = postCtx `mappend` bodyField "description"
            posts <- fmap (take 10) . recentFirst =<<
                loadAllSnapshots "posts/*" "content"
            renderAtom feedConfiguration feedCtx posts

    create ["rss.xml"] $ do
        route idRoute
        compile $ do
            let feedCtx = postCtx `mappend` bodyField "description"
            posts <- fmap (take 10) . recentFirst =<<
                loadAllSnapshots "posts/*" "content"
            renderRss feedConfiguration feedCtx posts

--------------------------------------------------------------------------------
postCtx :: Context String
postCtx =
    dateField "date" "%B %e, %Y" `mappend`
    teaserField "teaser" "content" `mappend`
    defaultContext

cleanURL :: Routes
cleanURL = customRoute fileToDirectory

fileToDirectory :: Identifier -> FilePath
fileToDirectory = (flip combine) "index.html" . dropExtension . toFilePath

toIndex :: Routes
toIndex = customRoute fileToIndex

fileToIndex :: Identifier -> FilePath
fileToIndex = (flip combine) "index.html" . dropFileName . toFilePath


feedConfiguration :: FeedConfiguration
feedConfiguration = FeedConfiguration
    { feedTitle       = "Xoltar"
    , feedDescription = "A blog by Bryn Keller about simplicity and clarity in software and in life" 
    , feedAuthorName  = "Bryn Keller"
    , feedAuthorEmail = "xoltar@xoltar.org"
    , feedRoot        = "http://www.xoltar.org"
    }

