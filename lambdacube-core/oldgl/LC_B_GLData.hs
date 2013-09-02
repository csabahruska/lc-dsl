module LC_B_GLData where

import Control.Applicative
import Control.Monad
import Data.ByteString.Char8 (ByteString)
import Data.IORef
import Data.List as L
import Data.Maybe
import Data.Trie as T
import Foreign 
--import qualified Data.IntMap as IM
import qualified Data.Map as Map
import qualified Data.Set as Set
import qualified Data.Vector as V

--import Control.DeepSeq

import Graphics.Rendering.OpenGL.Raw.Core32
    ( GLuint
    
    -- * FUNCTION APPLICATION related *
    -- render call
    , glDrawArrays
    , glDrawElements
    , gl_LINES
    , gl_LINES_ADJACENCY
    , gl_LINE_STRIP
    , gl_LINE_STRIP_ADJACENCY
    , gl_POINTS
    , gl_TRIANGLES
    , gl_TRIANGLES_ADJACENCY
    , gl_TRIANGLE_FAN
    , gl_TRIANGLE_STRIP
    , gl_TRIANGLE_STRIP_ADJACENCY

    -- * BUFFER related *
    -- buffer data
    , glBindBuffer
    , glBindVertexArray
    , glBufferData
    , glBufferSubData
    , glGenBuffers
    , glGenVertexArrays
    , gl_ARRAY_BUFFER
    , gl_ELEMENT_ARRAY_BUFFER
    , gl_STATIC_DRAW

    -- * TEXTURE related *
    -- texture data
    , glBindTexture
    , glGenTextures
    , glGenerateMipmap
    , glPixelStorei
    , glTexImage2D
    , glTexParameteri
    , gl_CLAMP_TO_EDGE
    , gl_LINEAR
    , gl_LINEAR_MIPMAP_LINEAR
    , gl_REPEAT
    , gl_RGB
    , gl_RGBA
    , gl_RGBA8
    , gl_TEXTURE_2D
    , gl_TEXTURE_BASE_LEVEL
    , gl_TEXTURE_MAG_FILTER
    , gl_TEXTURE_MAX_LEVEL
    , gl_TEXTURE_MIN_FILTER
    , gl_TEXTURE_WRAP_S
    , gl_TEXTURE_WRAP_T
    , gl_UNPACK_ALIGNMENT
    , gl_UNSIGNED_BYTE
    )

import Data.Word
import Data.Bitmap.Pure

import LC_B_GLType
import LC_B_GLUtil
import LC_G_APIType
import LC_U_APIType
import LC_U_DeBruijn

-- Buffer
compileBuffer :: [Array] -> IO Buffer
compileBuffer arrs = do
    let calcDesc (offset,setters,descs) (Array arrType cnt setter) =
          let size = cnt * sizeOfArrayType arrType
          in (size + offset, (offset,size,setter):setters, ArrayDesc arrType cnt offset size:descs)
        (bufSize,arrSetters,arrDescs) = foldl' calcDesc (0,[],[]) arrs
    bo <- alloca $! \pbo -> glGenBuffers 1 pbo >> peek pbo
    glBindBuffer gl_ARRAY_BUFFER bo
    glBufferData gl_ARRAY_BUFFER (fromIntegral bufSize) nullPtr gl_STATIC_DRAW
    forM_ arrSetters $! \(offset,size,setter) -> setter $! glBufferSubData gl_ARRAY_BUFFER (fromIntegral offset) (fromIntegral size)
    glBindBuffer gl_ARRAY_BUFFER 0
    return $! Buffer (V.fromList $! reverse arrDescs) bo

updateBuffer :: Buffer -> [(Int,Array)] -> IO ()
updateBuffer (Buffer arrDescs bo) arrs = do
    glBindBuffer gl_ARRAY_BUFFER bo
    forM arrs $ \(i,Array arrType cnt setter) -> do
        let ArrayDesc ty len offset size = arrDescs V.! i
        when (ty == arrType && cnt == len) $
            setter $! glBufferSubData gl_ARRAY_BUFFER (fromIntegral offset) (fromIntegral size)
    glBindBuffer gl_ARRAY_BUFFER 0

bufferSize :: Buffer -> Int
bufferSize = V.length . bufArrays

arraySize :: Buffer -> Int -> Int
arraySize buf arrIdx = arrLength $! bufArrays buf V.! arrIdx

arrayType :: Buffer -> Int -> ArrayType
arrayType buf arrIdx = arrType $! bufArrays buf V.! arrIdx

-- question: should we render the full stream?
--  answer: YES
-- Object
nullObject :: Object
nullObject = unsafePerformIO $ Object "" T.empty 0 <$> newIORef False

addObject :: Renderer -> ByteString -> Primitive -> Maybe (IndexStream Buffer) -> Trie (Stream Buffer) -> [ByteString] -> IO Object
addObject renderer slotName prim objIndices objAttributes objUniforms =
  if (not $ T.member slotName $! slotUniform renderer) then do
    putStrLn $ "WARNING: unknown slot name: " ++ show slotName
    return nullObject
  else do
    -- validate
    let Just (slotType,sType) = T.lookup slotName $ slotStream renderer
        objSType = fmap streamToInputType objAttributes
        primType = case prim of
            TriangleStrip           -> Triangles
            TriangleList            -> Triangles
            TriangleFan             -> Triangles
            LineStrip               -> Lines
            LineList                -> Lines
            PointList               -> Points
            TriangleStripAdjacency  -> TrianglesAdjacency
            TriangleListAdjacency   -> TrianglesAdjacency
            LineStripAdjacency      -> LinesAdjacency
            LineListAdjacency       -> LinesAdjacency
        primGL = case prim of
            TriangleStrip           -> gl_TRIANGLE_STRIP
            TriangleList            -> gl_TRIANGLES
            TriangleFan             -> gl_TRIANGLE_FAN
            LineStrip               -> gl_LINE_STRIP
            LineList                -> gl_LINES
            PointList               -> gl_POINTS
            TriangleStripAdjacency  -> gl_TRIANGLE_STRIP_ADJACENCY
            TriangleListAdjacency   -> gl_TRIANGLES_ADJACENCY
            LineStripAdjacency      -> gl_LINE_STRIP_ADJACENCY
            LineListAdjacency       -> gl_LINES_ADJACENCY
        streamCounts = [c | Stream _ _ _ _ c <- T.elems objAttributes]
        count = head streamCounts

    when (slotType /= primType) $ fail $ "addObject: primitive type mismatch: " ++ show (slotType,primType)
    when (objSType /= sType) $ fail $ unlines
        [ "addObject: attribute mismatch"
        , "expected:"
        , "  " ++ show sType
        , "actual:"
        , "  " ++ show objSType
        ]
    when (L.null streamCounts) $ fail "addObject: missing stream attribute, a least one stream attribute is required!"
    when (L.or [c /= count | c <- streamCounts]) $ fail "addObject: streams should have the same length!"

    -- validate index type if presented and create draw action
    (iSetup,draw) <- case objIndices of
        Nothing -> return (glBindBuffer gl_ELEMENT_ARRAY_BUFFER 0, glDrawArrays primGL 0 (fromIntegral count))
        Just (IndexStream (Buffer arrs bo) arrIdx start idxCount) -> do
            -- setup index buffer
            let ArrayDesc arrType arrLen arrOffs arrSize = arrs V.! arrIdx
                glType = arrayTypeToGLType arrType
                ptr    = intPtrToPtr $! fromIntegral (arrOffs + start * sizeOfArrayType arrType)
            -- validate index type
            when (notElem arrType [ArrWord8, ArrWord16, ArrWord32]) $ fail "addObject: index type should be unsigned integer type"
            return (glBindBuffer gl_ELEMENT_ARRAY_BUFFER bo, glDrawElements primGL (fromIntegral idxCount) glType ptr)

    -- implementation
    let renderDescriptorMap = renderDescriptor renderer
        uniformType     = T.fromList $ concat [T.toList t | (_,t) <- T.toList $ slotUniform renderer]
        mkUSetup        = mkUniformSetup renderer
        globalUNames    = Set.toList $! (Set.fromList $! T.keys uniformType) Set.\\ (Set.fromList objUniforms)
        rendState       = renderState renderer
        
    stateIORef <- newIORef True
    (mkObjUSetup,objUSetters) <- unzip <$> (sequence [mkUniformSetter rendState t | n <- objUniforms, t <- maybeToList $ T.lookup n uniformType])
    let objUSetterTrie = T.fromList $! zip objUniforms objUSetters
    
        mkDrawAction :: Exp -> IO (GLuint,IO ())
        mkDrawAction gp = do
            let Just rd = Map.lookup gp renderDescriptorMap
                sLocs   = streamLocation rd
                uLocs   = uniformLocation rd
                -- stream setup action
                sSetup          = sequence_ [ mkSSetter t loc s 
                                            | (n,s) <- T.toList objAttributes
                                            ,     t <- maybeToList $ T.lookup n sType
                                            ,   loc <- maybeToList $ T.lookup n sLocs
                                            ]
                -- global uniform setup
                {-
                globalUSetup    = sequence_ [ mkUS loc 
                                            | n <- globalUNames
                                            , let Just mkUS = T.lookup n mkUSetup
                                            , loc <- maybeToList $ T.lookup n uLocs
                                            ]
                -}
                globalUSetup    = V.sequence_ $ V.fromList
                                            [ mkUS loc
                                            | n <- globalUNames
                                            , let Just mkUS = T.lookup n mkUSetup
                                            , loc <- maybeToList $ T.lookup n uLocs
                                            ]
                -- object uniform setup
                objUSetup       = sequence_ [ mkOUS loc
                                            | (n,mkOUS) <- zip objUniforms mkObjUSetup
                                            , loc <- maybeToList $ T.lookup n uLocs
                                            ]
            --print sLocs
            -- create Vertex Array Object
            vao <- alloca $! \pvao -> glGenVertexArrays 1 pvao >> peek pvao
            glBindVertexArray vao
            sSetup -- setup vertex attributes
            iSetup -- setup index buffer
            let renderFun = readIORef stateIORef >>= \enabled -> when enabled $ do
                    --print "draw object"
                    --putStrLn $ "  setup global uniforms: " ++ show [n | n <- globalUNames, T.member n uLocs]
                    globalUSetup            -- setup uniforms
                    --putStrLn $ "  setup object uniforms: " ++ show [n | n <- objUniforms, T.member n uLocs]
                    objUSetup
                    glBindVertexArray vao   -- setup stream input (aka object attributes)
                    draw                    -- execute draw function
            return (vao,renderFun)

        Just (SlotDescriptor gps objSetRef) = T.lookup slotName (slotDescriptor renderer)
        gpList = Set.toList gps
    {-
        - create the object draw action for every Accumulate node
        - update ObjectSet's draw action lists
    -}
    --print sType
    (vaoList,drawList) <- unzip <$> mapM mkDrawAction gpList
    objID <- readIORef (objectIDSeed renderer)
    modifyIORef (objectIDSeed renderer) (+1)
    let obj = Object
            { objectSlotName        = slotName
            , objectUniformSetter   = objUSetterTrie
            , objectID              = objID
            , objectEnabledIORef    = stateIORef
            }

    -- add object to slot's object set
    modifyIORef objSetRef $ \s -> Set.insert obj s

    -- add draw object action to list
    forM_ (zip gpList drawList) $ \(gp,draw) -> do
        --print ("add", vaoList)
        let Just rd = Map.lookup gp renderDescriptorMap
        modifyIORef (drawObjectsIORef rd) $ \(ObjectSet _ drawMap) ->
            let drawMap' = Map.insert obj draw drawMap
            in ObjectSet (sequence_ $ Map.elems drawMap') drawMap'

    return obj

removeObject :: Renderer -> Object -> IO ()
removeObject rend obj = do
    let Just (SlotDescriptor gps objSetRef) = T.lookup (objectSlotName obj) (slotDescriptor rend)
        renderDescriptorMap = renderDescriptor rend

    -- remove object from slot's object set
    modifyIORef objSetRef $ \s -> Set.delete obj s

    -- remove draw object action from list
    forM_ (Set.toList gps) $ \gp -> do
        let Just rd = Map.lookup gp renderDescriptorMap
        modifyIORef (drawObjectsIORef rd) $ \(ObjectSet _ drawMap) ->
            let drawMap' = Map.delete obj drawMap
            in ObjectSet (sequence_ $ Map.elems drawMap') drawMap'

enableObject :: Object -> Bool -> IO ()
enableObject obj b = writeIORef (objectEnabledIORef obj) b

-- Texture

-- FIXME: Temporary implemenation
compileTexture2DRGBAF :: Bool -> Bool -> Bitmap Word8 -> IO TextureData
compileTexture2DRGBAF isMip isClamped bitmap = do
    glPixelStorei gl_UNPACK_ALIGNMENT 1
    to <- alloca $! \pto -> glGenTextures 1 pto >> peek pto
    glBindTexture gl_TEXTURE_2D to
    let (width,height) = bitmapSize bitmap
        wrapMode = case isClamped of
            True    -> gl_CLAMP_TO_EDGE
            False   -> gl_REPEAT
        (minFilter,maxLevel) = case isMip of
            False   -> (gl_LINEAR,0)
            True    -> (gl_LINEAR_MIPMAP_LINEAR, floor $ log (fromIntegral $ max width height) / log 2)
    glTexParameteri gl_TEXTURE_2D gl_TEXTURE_WRAP_S $ fromIntegral wrapMode
    glTexParameteri gl_TEXTURE_2D gl_TEXTURE_WRAP_T $ fromIntegral wrapMode
    glTexParameteri gl_TEXTURE_2D gl_TEXTURE_MIN_FILTER $ fromIntegral minFilter
    glTexParameteri gl_TEXTURE_2D gl_TEXTURE_MAG_FILTER $ fromIntegral gl_LINEAR
    glTexParameteri gl_TEXTURE_2D gl_TEXTURE_BASE_LEVEL 0
    glTexParameteri gl_TEXTURE_2D gl_TEXTURE_MAX_LEVEL $ fromIntegral maxLevel
    withBitmap bitmap $ \(w,h) nchn 0 ptr -> do
        let internalFormat  = fromIntegral gl_RGBA8
            dataFormat      = fromIntegral $ case nchn of
                3   -> gl_RGB
                4   -> gl_RGBA
                _   -> error "unsupported texture format!"
        glTexImage2D gl_TEXTURE_2D 0 internalFormat (fromIntegral w) (fromIntegral h) 0 dataFormat gl_UNSIGNED_BYTE $ castPtr ptr
    when isMip $ glGenerateMipmap gl_TEXTURE_2D
    return $ TextureData to
