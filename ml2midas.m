function N = ml2midas(file,data,format,xstart,xdelta,xunits,ystart,ydelta,yunits,timecode)
% Usage: N = ml2midas(file,data,format,xstart,xdelta,xunits,ystart,ydelta,yunits,timecode)
%
% Simple function to write Matlab workspace data to X-Midas bluefile.
%
% file...........Name of output Bluefile
% data...........Array to be written out, 1-d vector is written to type 1000 
%                file, 2-d arrays to type 2000 where each row is one subframe
% format.........Optional digraph, default 'SD' for real data, 'CD' for complex
%                Supported: 'SB','SI','SL','SX','SF','SD','CI','CL','CF','CX','CD'
% xstart.........Optional abscissa start, default 0
% xdelta.........Optional abscissa increment, default 1
% xunits.........Optional abscissa units, default 0 (unitless)
% ystart.........Optional type 2000 secondary start, default 0
% ydelta.........Optional type 2000 increment, default 1
% yunits.........Optional type 2000 units, default 0 (unitless)
% timecode.......Optional j1950 timecode (one double precision float)
% N..............Return value containing number of elements written
%
% Example: Generate a type 1000 Bluefile containing the 25th root length-139 
% Zadoff-Chu sequence.
%
%   zc = exp(-j*pi*25*(0:138).*(1:139)/139).';
%   N = ml2midas('zcfile.tmp',zc);
%
% Now read back the file:
%
%   [data,hdr] = midas2ml('zcfile.tmp');
%
%  Compare:
%
%   all(data == zc)
%   ans =  1
%

if nargin < 10, timecode = 0; end;
if nargin < 9, yunits = 0; end;
if nargin < 8, ydelta = 1; end;
if nargin < 7, ystart = 0; end;
if nargin < 6, xunits = 0; end;
if nargin < 5, xdelta = 1; end;
if nargin < 4, xstart = 0; end;
if nargin < 3
  if isreal(data)
    format = 'SD';
  else
    format = 'CD';
  end;
end;
if min(size(data)) == 1, 
  type = 1000;
  subsize = 0;
else
  type = 2000;
  subsize = size(data,2);  % treat each row as a subrecord
end;

X.xstart = xstart;
X.xdelta = xdelta;
X.xunits = xunits;
Y.ystart = ystart;
Y.ydelta = ydelta;
Y.yunits = yunits;
nelem = length(data(:));

fid = fopen(file,'wb');
stat = write_header(fid,type,format,X,Y,nelem,subsize,timecode);
N = write_data(fid,data,stat);
fclose(fid);

% << End main >>

function stat = write_header(fid,type,format,X,Y,nelem,subsize,timecode)

  if format(1) == 'S'
    elem_per_pt = 1;
    cplx = 0;
  else
    elem_per_pt = 2;
    cplx = 1;
  end;

  if format(2) == 'B'
    dtype = 'int8';
    bpa = 1;
  elseif format(2) == 'I'
    dtype = 'int16';
    bpa = 2;
  elseif format(2) == 'L'
    dtype = 'int32';
    bpa = 4;
  elseif format(2) == 'F'
    dtype = 'single';
    bpa = 4;
  elseif format(2) == 'X'
    dtype = 'int64';
    bpa = 8;
  elseif format(2) == 'D'
    dtype = 'double';
    bpa = 8;
  end;

  bpe = bpa * elem_per_pt;
  data_size = nelem * bpe;

  % Fixed header
  fwrite(fid,zeros(1,512),'uchar');
  fseek(fid,0,'bof');
  fwrite(fid,'BLUEEEEIEEEI','char');  % offset=0, size=12
  fseek(fid,32,'bof');
  fwrite(fid,512,'double'); % data_start, offset=32, size=8
  fwrite(fid,data_size,'double'); % offset=40, size=8
  fwrite(fid,type,'int32'); % offset=48, size=4
  fwrite(fid,format,'char'); % offset=52, size=1
  if timecode > 0
    fseek(fid,56,'bof');
    fwrite(fid,timecode,'double'); % offset=56, size=8
  end

  % Adjunct header
  fseek(fid,256,'bof');
  fwrite(fid,X.xstart,'double'); % adj offset=0, size=8
  fwrite(fid,X.xdelta,'double'); % adj offset=8, size=8
  fwrite(fid,X.xunits,'int32'); % adj offset=16, size=4
  if type == 2000
    fwrite(fid,subsize,'int32'); % adj offset=20, size=4
    fwrite(fid,Y.ystart,'double'); % adj offset=24, size=8
    fwrite(fid,Y.ydelta,'double'); % adj offset=32, size=8
    fwrite(fid,Y.yunits,'int32'); % adj offset=40, size=4
  end;

  stat.dtype = dtype;
  stat.data_start = 512;
  stat.data_size = data_size;
  stat.elem_per_pt = elem_per_pt;
  stat.cplx = cplx;

%%%%
function N = write_data(fid,data,stat)

  if min(size(data)) > 1
    % type 2000 - treat rows as subrecords (frames)
    data = data.';
    data = data(:);
  end;
  if stat.cplx
    d = [real(data(:)).' ; imag(data(:)).'];
    d = d(:);
  else
    d = real(data);
  end;
  fseek(fid,stat.data_start,'bof');
  N = fwrite(fid,d,stat.dtype);
  N = N / stat.elem_per_pt;
