function xraster(z, xstart, xdelta, ystart, ydelta, clims)
% Usage: xraster(z, xstart, xdelta, ystart, ydelta, clims)
%
% Plot an X-Midas style raster
%
% z..........N-by-M array of data to plot
%            where N defines the y-axis
%            and M the x-axis
%
% xstart.....optional metadata defining the
%            starting abscissa value
%
% xdelta.....optional metadata defining the
%            spacing between abscissa points
%
% ystart.....optional metadata defining the
%            starting ordinate value
%
% ydelta.....optional metadata defining the
%            spacing between ordinate points
%
% clims......optional two-element vector of form [cmin cmax]
%            to set the data scaling in the colormap
%

if nargin < 6 || isempty(clims)
  clims = [];
end
if nargin < 5 || isempty(ydelta)
  ydelta = 1;
end
if nargin < 4 || isempty(ystart)
  ystart = 1;
end
if nargin < 3 || isempty(xdelta)
  xdelta = 1;
end
if nargin < 2 || isempty(xstart)
  xstart = 1;
end
if nargin == 0 || isempty(z)
  help xraster
  return
end

if isoctave
  if size(z,1) > 9999
    fprintf(2, 'Max number of rows (9999) exceeded: %d. Plotting first 9999 rows only.\n', size(z,1));
    z = z(1:9999,:);
  end
end

if ~isreal(z)
 z = abs(z);
end

sz = size(z);
num_frames = sz(1);
frame_size = sz(2);

x = xstart + (0:xdelta:xdelta*(frame_size-1));
y = ystart + (0:ydelta:ydelta*(num_frames-1));

if isoctave || ~isempty(clims)
  imagesc(x,y,z,clims);
else
  imagesc(x,y,z);
end
