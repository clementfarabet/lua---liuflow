-- 
-- Note: this bit of code is a simple wrapper around the optical-flow
-- algorithm developped/published by C.Liu:
--
-- C. Liu. Beyond Pixels: Exploring New Representations and Applications
-- for Motion Analysis. Doctoral Thesis. Massachusetts Institute of 
-- Technology. May 2009.
--
-- More at: http://people.csail.mit.edu/celiu/OpticalFlow/
--
-- Wrapper: Clement Farabet.
-- 

-- load C lib
require 'libliuflow'

local infer_help_desc =
[[Computes the optical flow of a pair of images, and returns
the norm and the direction fields, plus a warped version of the second
image, according to the flow field.

The flow field is computed using CG, as described in
"Exploring New Representations and Applications for Motion Analysis",
by C. Liu (Doctoral Thesis).
More at http://people.csail.mit.edu/celiu/OpticalFlow/

The input images must be a NxHxW tensor, where N is the number
of channels (colors).]]

------------------------------------------------------------
-- Liu's optical flow algorithm.
--
-- C. Liu. Beyond Pixels: Exploring New Representations and Applications
-- for Motion Analysis. Doctoral Thesis. Massachusetts Institute of 
-- Technology. May 2009.
--
-- To load: require 'liuflow'
--
-- @release 2010 Clement Farabet
------------------------------------------------------------
liuflow = {}

------------------------------------------------------------
-- Computes the optical flow of a pair of images, and returns
-- the norm and the direction fields, plus a warped version of the second
-- image, according to the flow field.
--
-- The flow field is computed using CG, as described in
-- "Exploring New Representations and Applications for Motion Analysis",
-- by C. Liu (Doctoral Thesis).
-- More at http://people.csail.mit.edu/celiu/OpticalFlow/
--
-- The input images must be a NxHxW tensor, where N is the number
-- of channels (colors).
--
-- @usage opticalFlow.infer() -- prints online help
--
-- @param pair  a pair of images (2 NxHxW tensor) [type = table]
   -- @param image1  the first image (NxHxW tensor) [type = torch.Tensor]
-- @param image2  the second image (NxHxW tensor) [type = torch.Tensor]
-- @param alpha  regularization weight [default = 0.01] [type = number]
-- @param ratio  downsample ratio [default = 0.75] [type = number]
-- @param minWidth  width of the coarsest level [default = 30] [type = number]
-- @param nOuterFPIterations  number of outer fixed-point iterations [default = 15] [type = number]
-- @param nInnerFPIterations  number of inner fixed-point iterations [default = 1] [type = number]
-- @param nCGIterations  number of CG iterations [default = 20] [type = number]
------------------------------------------------------------
liuflow.infer = function(...)
           -- check args
           local args, pair, img1, img2, alpha, ratio, minWidth, 
           nOuterFPIterations, nInnerFPIterations, nCGIterations = dok.unpack(
              {...},
              'opticalFlow.infer',
              infer_help_desc,
              {arg='pair', type='table', help='a pair of images (2 NxHxW tensor)'},
              {arg='image1', type='torch.Tensor', help='the first image (NxHxW tensor)'},
              {arg='image2', type='torch.Tensor', help='the second image (NxHxW tensor)'},
              {arg='alpha', type='number', help='regularization weight', default=0.01},
              {arg='ratio', type='number', help='downsample ratio', default=0.75},
              {arg='minWidth', type='number', help='width of the coarsest level', default=30},
              {arg='nOuterFPIterations', type='number', help='number of outer fixed-point iterations', default=15},
              {arg='nInnerFPIterations', type='number', help='number of inner fixed-point iterations', default=1},
              {arg='nCGIterations', type='number', help='number of CG iterations', default=20}
           )
           
           -- pair ?
           if pair then 
              img1 = pair[1]
              img2 = pair[2]
           end

           -- check dims
           if img1:nDimension() ~= 3 then
              error('image should be a NxHxW tensor')
           end

           -- compute flow
           local flow_x, flow_y, warp = libliuflow.infer(img1, img2,
                                                         alpha, ratio, minWidth,
                                                         nOuterFPIterations, nInnerFPIterations,
                                                         nCGIterations)

	   local flow_norm  = liuflow.computeNorm(flow_x,flow_y)
	   local flow_angle = liuflow.computeAngle(flow_x,flow_y)

           -- return results
           return flow_norm, flow_angle, warp, flow_x, flow_y
        end

-- warper
liuflow.warp = function(...)
          local args, inp, vx, vy = dok.unpack(
             {...},
             'opticalFlow.warp', 
             'warps an image according to a flow field:\n'
                ..'if flow was computed from img1->img2, then warp(img2,vx,vy) will compute\n'
                ..'a reconstruction of img1',
             {arg='image', type='torch.Tensor', help='input image (NxHxW tensor)', req=true},
             {arg='flow_x', type='torch.Tensor', help='x component of flow field', req=true},
             {arg='flow_y', type='torch.Tensor', help='y component of flow field', req=true}
          )
          if inp:nDimension() ~= 3 then
             xerror('image should be a NxHxW tensor',nil,args.usage)
          end
          return libliuflow.warp(inp, vx, vy)
       end

------------------------------------------------------------
-- Computes the optical flow on some example images
--
-- @see                  opticalFlow.infer
------------------------------------------------------------
liuflow.testme = function()
            require 'image'

            local img1 = image.load(paths.concat(paths.install_lua_path, 'liuflow/img1.jpg')):float()
            local img2 = image.load(paths.concat(paths.install_lua_path, 'liuflow/img2.jpg')):float()
            local img1s = image.scale(img1,img1:size(3)/2,img1:size(2)/2)
            local img2s = image.scale(img2,img1:size(3)/2,img1:size(2)/2)
            
            print('computing optical on ' .. img1s:size(3) .. 'x' .. img1s:size(2) .. ' image')

            local resn,resa,warp,resx,resy = liuflow.infer{ pair={img1s,img2s},
                                                            alpha=0.005,
                                                            ratio=0.6,
                                                            minWidth=50,
                                                            nOuterFPIterations=6,
                                                            nInnerFPIterations=1,
                                                            nCGIterations=40 }

            local resn_q = resn:clone():div(resn:max()):mul(6):floor():div(8)
            local resa_q = resa:clone():div(360/16):floor():mul(360/16)
            
            image.display{image={img1s, liuflow.field2rgb(resn,resa), 
                                 img1s, (img2s-img1s):abs(),
                                 img2s, liuflow.field2rgb(resn_q,resa_q), 
                                 warp, (warp-img1s):abs()}, 
                              zoom=1,
                              min=0, max=1,
                              nrow=4,
                              legends={'input 1', 'flow field', 'input 1', 
                                       'input 1 - input 2',
                                       'input 2', 'quantized flow field', 
                                       'warped(input 2)', 
                                       'input 1 - warped(input 2)'},
                              legend="optical flow, method = C.Liu"}
            
            return resn, resa, warp
         end

------------------------------------------------------------
-- computes norm (size) of flow field from flow_x and flow_y,
--
-- @usage opticalFlow.computeNorm() -- prints online help
--
-- @param flow_x  flow field (x), (WxH) [required] [type = torch.Tensor]
-- @param flow_y  flow field (y), (WxH) [required] [type = torch.Tensor]
------------------------------------------------------------
liuflow.computeNorm = function(...)
                 -- check args
                 local args, flow_x, flow_y = dok.unpack(
                    {...},
                    'opticalFlow.computeNorm',
                    'computes norm (size) of flow field from flow_x and flow_y,\n',
                    {arg='flow_x', type='torch.Tensor', help='flow field (x), (WxH)', req=true},
                    {arg='flow_y', type='torch.Tensor', help='flow field (y), (WxH)', req=true}
                 )
                 local flow_norm = flow_y:clone():cmul(flow_y)
                 local x_squared = flow_x:clone():cmul(flow_x)
                 flow_norm:add(x_squared):sqrt()
                 return flow_norm
              end

------------------------------------------------------------
-- computes angle (direction) of flow field from flow_x and flow_y,
--
-- @usage opticalFlow.computeAngle() -- prints online help
--
-- @param flow_x  flow field (x), (WxH) [required] [type = torch.Tensor]
-- @param flow_y  flow field (y), (WxH) [required] [type = torch.Tensor]
------------------------------------------------------------
liuflow.computeAngle = function(...)
                  -- check args
                  local args, flow_x, flow_y = dok.unpack(
                     {...},
                     'opticalFlow.computeAngle',
                     'computes angle (direction) of flow field from flow_x and flow_y,\n',
                     {arg='flow_x', type='torch.Tensor', help='flow field (x), (WxH)', req=true},
                     {arg='flow_y', type='torch.Tensor', help='flow field (y), (WxH)', req=true}
                  )
                  local flow_angle = flow_y:clone():cdiv(flow_x):abs():atan():mul(180/math.pi)
                  flow_angle:map2(flow_x, flow_y, function(h,x,y)
                                                     if x == 0 and y >= 0 then
                                                        return 90
                                                     elseif x == 0 and y <= 0 then
                                                        return 270
                                                     elseif x >= 0 and y >= 0 then
                                                        -- all good
                                                     elseif x >= 0 and y < 0 then
                                                        return 360 - h
                                                     elseif x < 0 and y >= 0 then
                                                        return 180 - h
                                                     elseif x < 0 and y < 0 then
                                                        return 180 + h
                                                     end
                                                  end)
                  return flow_angle
               end

------------------------------------------------------------
-- merges Norm and Angle flow fields into a single RGB image,
-- where saturation=intensity, and hue=direction
--
-- @usage opticalFlow.field2rgb() -- prints online help
--
-- @param norm  flow field (norm), (WxH) [required] [type = torch.Tensor]
-- @param angle  flow field (angle), (WxH) [required] [type = torch.Tensor]
-- @param max  if not provided, norm:max() is used [type = number]
-- @param legend  prints a legend on the image [type = boolean]
------------------------------------------------------------
liuflow.field2rgb = function (...)
               -- check args
               local args, norm, angle, max, legend = dok.unpack(
                  {...},
                  'opticalFlow.field2rgb',
                  'merges Norm and Angle flow fields into a single RGB image,\n'
                     .. 'where saturation=intensity, and hue=direction',
                  {arg='norm', type='torch.Tensor', help='flow field (norm), (WxH)', req=true},
                  {arg='angle', type='torch.Tensor', help='flow field (angle), (WxH)', req=true},
                  {arg='max', type='number', help='if not provided, norm:max() is used'},
                  {arg='legend', type='boolean', help='prints a legend on the image', default=false}
               )

               -- max
               local saturate = false
               if max then saturate = true end
               max = math.max(max or norm:max(), 1e-2)

               -- redim?
               if norm:nDimension() == 3 then
                  norm = norm[1]
               end
               if angle:nDimension() == 3 then
                  angle = angle[1]
               end

               -- merge them into an HSL image
               local hsl = torch.Tensor(3, norm:size(1), norm:size(2))
               -- hue = angle:
               hsl:select(1,1):copy(angle):div(360)
               -- saturation = normalized intensity:
               hsl:select(1,2):copy(norm):div(max)
               if saturate then hsl:select(1,2):tanh() end
               -- light varies inversely from saturation (null flow = white):
               hsl:select(1,3):copy(hsl:select(1,2)):mul(-0.5):add(1)

               -- convert HSL to RGB
               local rgb = image.hsl2rgb(hsl)

               -- legend
               if legend then
                  _legend_ = _legend_
                     or image.load(paths.concat(paths.install_lua_path, 'liuflow/legend.png'))
                  local legend = image.scale(_legend_, hsl:size(2)/8, hsl:size(2)/8)
                  rgb:narrow(3,1,legend:size(2)):narrow(2,hsl:size(2)-legend:size(2)+1,legend:size(2)):copy(legend)
               end

               -- done
               return rgb
            end

------------------------------------------------------------
-- Simplifies display of flow field in HSV colorspace when the
-- available field is in x,y displacement
--
-- @usage opticalFlow.xy2rgb() -- prints online help
--
-- @param x  flow field (x), (WxH) [required] [type = torch.Tensor]
-- @param y  flow field (y), (WxH) [required] [type = torch.Tensor]
------------------------------------------------------------
liuflow.xy2rgb = function (...)
            -- check args
            local args, x, y, max = dok.unpack(
               {...},
               'opticalFlow.xy2rgb',
               'merges x and y flow fields into a single RGB image,\n'
                  .. 'where saturation=intensity, and hue=direction',
               {arg='x', type='torch.Tensor', help='flow field (norm), (WxH)', req=true},
               {arg='y', type='torch.Tensor', help='flow field (angle), (WxH)', req=true},
               {arg='max', type='number', help='if not provided, norm:max() is used'}
            )
            
            local norm = liuflow.computeNorm(x,y)
            local angle = liuflow.computeAngle(x,y)
            return liuflow.field2rgb(norm,angle,max)
         end
