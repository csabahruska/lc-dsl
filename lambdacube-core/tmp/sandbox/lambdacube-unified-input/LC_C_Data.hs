module LC_C_Data where

import TypeLevel.Number.Nat

import LC_U_APIType
import LC_U_PrimFun
import qualified LC_T_APIType as T
import qualified LC_T_PrimFun as T

convertColorArity :: T.ColorArity a -> ColorArity
convertColorArity v = case v of
    T.Red   -> Red
    T.RG    -> RG
    T.RGB   -> RGB
    T.RGBA  -> RGBA

convertTextureDataType :: T.TextureDataType t ar -> TextureDataType
convertTextureDataType v = case v of
    T.FloatTexel a  -> FloatTexel   (convertColorArity a)
    T.IntTexel a    -> IntTexel     (convertColorArity a)
    T.WordTexel a   -> WordTexel    (convertColorArity a)
    T.ShadowTexel   -> ShadowTexel

convertTextureType :: T.TextureType dim mip arr layerCount t ar -> TextureType
convertTextureType v = case v of
    T.Texture1D a b     -> Texture1D     (convertTextureDataType a) (toInt b)
    T.Texture2D a b     -> Texture2D     (convertTextureDataType a) (toInt b)
    T.Texture3D a       -> Texture3D     (convertTextureDataType a)
    T.TextureCube a     -> TextureCube   (convertTextureDataType a)
    T.TextureRect a     -> TextureRect   (convertTextureDataType a)
    T.Texture2DMS a b   -> Texture2DMS   (convertTextureDataType a) (toInt b)
    T.TextureBuffer a   -> TextureBuffer (convertTextureDataType a)

convertMipMap :: T.MipMap t -> MipMap
convertMipMap v = case v of
    T.NoMip         -> NoMip
    T.Mip a b       -> Mip a b
    T.AutoMip a b   -> AutoMip a b

convertRasterContext :: T.RasterContext p -> RasterContext
convertRasterContext v = case v of
    T.PointCtx              -> PointCtx
    T.LineCtx a b           -> LineCtx a b
    T.TriangleCtx a b c d   -> TriangleCtx a b c d

convertBlending :: T.Blending c -> Blending
convertBlending v = case v of 
    T.NoBlending        -> NoBlending
    T.BlendLogicOp a    -> BlendLogicOp a
    T.Blend a b c       -> Blend a b c

convertFetchPrimitive :: T.FetchPrimitive a b -> FetchPrimitive
convertFetchPrimitive v = case v of
    T.Points                    -> Points
    T.LineStrip                 -> LineStrip
    T.LineLoop                  -> LineLoop
    T.Lines                     -> Lines
    T.TriangleStrip             -> TriangleStrip
    T.TriangleFan               -> TriangleFan
    T.Triangles                 -> Triangles
    T.LinesAdjacency            -> LinesAdjacency
    T.LineStripAdjacency        -> LineStripAdjacency
    T.TrianglesAdjacency        -> TrianglesAdjacency
    T.TriangleStripAdjacency    -> TriangleStripAdjacency

convertOutputPrimitive :: T.OutputPrimitive a -> OutputPrimitive
convertOutputPrimitive v = case v of
    T.TrianglesOutput   -> TrianglesOutput
    T.LinesOutput       -> LinesOutput
    T.PointsOutput      -> PointsOutput

{-
convertAccumulationContext :: T.AccumulationContext b -> AccumulationContext
convertAccumulationContext (T.AccumulationContext n ops) = AccumulationContext n $ cvt ops
  where
    cvt :: FlatTuple Typeable T.FragmentOperation b -> [FragmentOperation]
    cvt ZT                          = []
    cvt (T.DepthOp a b :. xs)       = DepthOp a b : cvt xs
    cvt (T.StencilOp a b c :. xs)   = StencilOp a b c : cvt xs
    cvt (T.ColorOp a b :. xs)       = ColorOp (convertBlending a) (T.toValue b) : cvt xs

convertFrameBuffer :: T.FrameBuffer layerCount t -> [Image]
convertFrameBuffer = cvt
  where
    cvt :: T.FrameBuffer layerCount t -> [Image]
    cvt ZT                          = []
    cvt (T.DepthImage a b:.xs)      = DepthImage (toInt a) b : cvt xs
    cvt (T.StencilImage a b:.xs)    = StencilImage (toInt a) b : cvt xs
    cvt (T.ColorImage a b:.xs)      = ColorImage (toInt a) (T.toValue b) : cvt xs
-}

convertPrimFun :: T.PrimFun a b -> PrimFun
convertPrimFun a = case a of
    -- Vec/Mat (de)construction
    T.PrimTupToV2                   -> PrimTupToV2
    T.PrimTupToV3                   -> PrimTupToV3
    T.PrimTupToV4                   -> PrimTupToV4
    T.PrimV2ToTup                   -> PrimV2ToTup
    T.PrimV3ToTup                   -> PrimV3ToTup
    T.PrimV4ToTup                   -> PrimV4ToTup

    -- Arithmetic Functions (componentwise)
    T.PrimAdd                       -> PrimAdd 
    T.PrimAddS                      -> PrimAddS
    T.PrimSub                       -> PrimSub 
    T.PrimSubS                      -> PrimSubS  
    T.PrimMul                       -> PrimMul 
    T.PrimMulS                      -> PrimMulS
    T.PrimDiv                       -> PrimDiv 
    T.PrimDivS                      -> PrimDivS
    T.PrimNeg                       -> PrimNeg 
    T.PrimMod                       -> PrimMod 
    T.PrimModS                      -> PrimModS

    -- Bit-wise Functions
    T.PrimBAnd                      -> PrimBAnd    
    T.PrimBAndS                     -> PrimBAndS   
    T.PrimBOr                       -> PrimBOr     
    T.PrimBOrS                      -> PrimBOrS    
    T.PrimBXor                      -> PrimBXor    
    T.PrimBXorS                     -> PrimBXorS   
    T.PrimBNot                      -> PrimBNot    
    T.PrimBShiftL                   -> PrimBShiftL 
    T.PrimBShiftLS                  -> PrimBShiftLS
    T.PrimBShiftR                   -> PrimBShiftR 
    T.PrimBShiftRS                  -> PrimBShiftRS

    -- Logic Functions
    T.PrimAnd                       -> PrimAnd
    T.PrimOr                        -> PrimOr 
    T.PrimXor                       -> PrimXor
    T.PrimNot                       -> PrimNot
    T.PrimAny                       -> PrimAny
    T.PrimAll                       -> PrimAll

    -- Angle and Trigonometry Functions
    T.PrimACos                      -> PrimACos   
    T.PrimACosH                     -> PrimACosH  
    T.PrimASin                      -> PrimASin   
    T.PrimASinH                     -> PrimASinH  
    T.PrimATan                      -> PrimATan   
    T.PrimATan2                     -> PrimATan2  
    T.PrimATanH                     -> PrimATanH  
    T.PrimCos                       -> PrimCos    
    T.PrimCosH                      -> PrimCosH   
    T.PrimDegrees                   -> PrimDegrees
    T.PrimRadians                   -> PrimRadians
    T.PrimSin                       -> PrimSin    
    T.PrimSinH                      -> PrimSinH   
    T.PrimTan                       -> PrimTan    
    T.PrimTanH                      -> PrimTanH   

    -- Exponential Functions
    T.PrimPow                       -> PrimPow    
    T.PrimExp                       -> PrimExp    
    T.PrimLog                       -> PrimLog    
    T.PrimExp2                      -> PrimExp2   
    T.PrimLog2                      -> PrimLog2   
    T.PrimSqrt                      -> PrimSqrt   
    T.PrimInvSqrt                   -> PrimInvSqrt

    -- Common Functions
    T.PrimIsNan                     -> PrimIsNan      
    T.PrimIsInf                     -> PrimIsInf      
    T.PrimAbs                       -> PrimAbs        
    T.PrimSign                      -> PrimSign       
    T.PrimFloor                     -> PrimFloor      
    T.PrimTrunc                     -> PrimTrunc      
    T.PrimRound                     -> PrimRound      
    T.PrimRoundEven                 -> PrimRoundEven  
    T.PrimCeil                      -> PrimCeil       
    T.PrimFract                     -> PrimFract      
    T.PrimModF                      -> PrimModF       
    T.PrimMin                       -> PrimMin        
    T.PrimMinS                      -> PrimMinS       
    T.PrimMax                       -> PrimMax        
    T.PrimMaxS                      -> PrimMaxS       
    T.PrimClamp                     -> PrimClamp      
    T.PrimClampS                    -> PrimClampS     
    T.PrimMix                       -> PrimMix        
    T.PrimMixS                      -> PrimMixS       
    T.PrimMixB                      -> PrimMixB       
    T.PrimStep                      -> PrimStep       
    T.PrimStepS                     -> PrimStepS      
    T.PrimSmoothStep                -> PrimSmoothStep 
    T.PrimSmoothStepS               -> PrimSmoothStepS

    -- Integer/Float Conversion Functions
    T.PrimFloatBitsToInt            -> PrimFloatBitsToInt   
    T.PrimFloatBitsToUInt           -> PrimFloatBitsToUInt  
    T.PrimIntBitsToFloat            -> PrimIntBitsToFloat   
    T.PrimUIntBitsToFloat           -> PrimUIntBitsToFloat  

    -- Geometric Functions
    T.PrimLength                    -> PrimLength     
    T.PrimDistance                  -> PrimDistance   
    T.PrimDot                       -> PrimDot        
    T.PrimCross                     -> PrimCross      
    T.PrimNormalize                 -> PrimNormalize  
    T.PrimFaceForward               -> PrimFaceForward
    T.PrimReflect                   -> PrimReflect    
    T.PrimRefract                   -> PrimRefract    

    -- Matrix Functions
    T.PrimTranspose                 -> PrimTranspose   
    T.PrimDeterminant               -> PrimDeterminant 
    T.PrimInverse                   -> PrimInverse     
    T.PrimOuterProduct              -> PrimOuterProduct
    T.PrimMulMatVec                 -> PrimMulMatVec   
    T.PrimMulVecMat                 -> PrimMulVecMat   
    T.PrimMulMatMat                 -> PrimMulMatMat   

    -- Vector and Scalar Relational Functions
    T.PrimLessThan                  -> PrimLessThan        
    T.PrimLessThanEqual             -> PrimLessThanEqual   
    T.PrimGreaterThan               -> PrimGreaterThan     
    T.PrimGreaterThanEqual          -> PrimGreaterThanEqual
    T.PrimEqualV                    -> PrimEqualV          
    T.PrimEqual                     -> PrimEqual           
    T.PrimNotEqualV                 -> PrimNotEqualV       
    T.PrimNotEqual                  -> PrimNotEqual        

    -- Fragment Processing Functions
    T.PrimDFdx                      -> PrimDFdx  
    T.PrimDFdy                      -> PrimDFdy  
    T.PrimFWidth                    -> PrimFWidth

    -- Noise Functions
    T.PrimNoise1                    -> PrimNoise1
    T.PrimNoise2                    -> PrimNoise2
    T.PrimNoise3                    -> PrimNoise3
    T.PrimNoise4                    -> PrimNoise4

    -- Texture Lookup Functions
    T.PrimTextureSize               -> PrimTextureSize
    T.PrimTexture                   -> PrimTexture
    T.PrimTextureB                  -> PrimTexture
    T.PrimTextureProj               -> PrimTextureProj
    T.PrimTextureProjB              -> PrimTextureProj
    T.PrimTextureLod                -> PrimTextureLod
    T.PrimTextureOffset             -> PrimTextureOffset
    T.PrimTextureOffsetB            -> PrimTextureOffset
    T.PrimTexelFetch                -> PrimTexelFetch
    T.PrimTexelFetchOffset          -> PrimTexelFetchOffset
    T.PrimTextureProjOffset         -> PrimTextureProjOffset
    T.PrimTextureProjOffsetB        -> PrimTextureProjOffset
    T.PrimTextureLodOffset          -> PrimTextureLodOffset
    T.PrimTextureProjLod            -> PrimTextureProjLod
    T.PrimTextureProjLodOffset      -> PrimTextureProjLodOffset
    T.PrimTextureGrad               -> PrimTextureGrad
    T.PrimTextureGradOffset         -> PrimTextureGradOffset
    T.PrimTextureProjGrad           -> PrimTextureProjGrad
    T.PrimTextureProjGradOffset     -> PrimTextureProjGradOffset 

    -- Builtin variables
    -- hint: modeled as functions with unit input to simplify AST
    -- vertex shader
    T.PrimVertexID                  -> PrimVertexID
    T.PrimInstanceID                -> PrimInstanceID
    -- geometry shader
    T.PrimPrimitiveIDIn             -> PrimPrimitiveIDIn
    -- fragment shader
    T.PrimFragCoord                 -> PrimFragCoord
    T.PrimFrontFacing               -> PrimFrontFacing
    T.PrimPointCoord                -> PrimPointCoord
    T.PrimPrimitiveID               -> PrimPrimitiveID

    -- Texture Construction
    T.PrimNewTexture                -> PrimNewTexture

    -- Sampler Construction
    T.PrimNewSampler                -> PrimNewSampler
