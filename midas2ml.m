function [data, hdr] = midas2ml(file, nstart, nend)
% Usage: [data, hdr] = midas2ml(file, nstart, nend)
%
% Simple function to read type 1000 or 2000 Bluefile into Matlab workspace.
%
% file.........Name of Bluefile to read
% nstart.......Optional zero-based index of first element to read
% nend.........Optional zero-based index of last element to read
% data.........Array containing Bluefile data
% hdr..........Structure containing Bluefile HCB information
%
% Type 1000 and 2000 files are supported.  Type 2000 data is read
% into a 2-d array in which each row contains one subframe.
%
% Example: Read a type 1000 Bluefile containing the 25th root length-139 
% Zadoff-Chu sequence.
%
% First generate the file:
%
%   N = ml2midas('zcfile.tmp',exp(-j*pi*25*(0:138).*(1:139)/139));
%
% Now read the file:
%
%   [data,hdr] = midas2ml('zcfile.tmp');
%
% Inspect the header:
%
%   hdr = 
%         type: 1000
%       format: 'CD'
%       xstart: 0
%       xdelta: 1
%       xunits: 0
%        nelem: 139
%

if nargin < 3, nend   = -1; end;
if nargin < 2, nstart = -1; end;

if rem(nstart, 1) || rem(nend, 1)
  fprintf(2,'ERROR: nstart and nend inputs must be integers\n');
  data = [];
  hdr = [];
  return
end

hdr = readheader(file);
if nstart == 0 && nend == 0
  data = [];
  if isfield(hdr,'timecode')
    hdr.timecode = format_timecode(hdr.timecode);
  end;
end
stat = getstat(hdr);
data = readdata(file,hdr,stat,nstart,nend);
hdr.nelem = stat.nelem;
if isfield(stat,'timecode')
  hdr.timecode = stat.timecode;
end;
if hdr.type == 2000
  hdr.size = stat.size;
end;
hdr = rmfield(hdr,'data_start');
hdr = rmfield(hdr,'data_size');

% << End Main >>

function hdr = readheader(file)

  % Fixed header
  hdr = [];
  fid = fopen(file,'r');
  endian = char(fread(fid,12,'char'))';
  hdr_endian = get_endian(endian(5:8));
  data_endian = get_endian(endian(9:12));
  fseek(fid,32,'bof');
  hdr.data_start = fread(fid,1,'double', 0, hdr_endian);
  hdr.data_size = fread(fid,1,'double', 0, hdr_endian);
  hdr.type = fread(fid,1,'int32', 0, hdr_endian);
  hdr.format = char(fread(fid,2,'char', 0, hdr_endian))';
  fseek(fid,56,'bof');
  timecode = fread(fid,1,'double', 0, hdr_endian);
  if timecode > 1
    hdr.timecode = timecode;
  end;
  
  % Adjunct header
  fseek(fid,256,'bof');
  hdr.xstart = fread(fid,1,'double', 0, hdr_endian);
  hdr.xdelta = fread(fid,1,'double', 0, hdr_endian);
  hdr.xunits = fread(fid,1,'int32', 0, hdr_endian);
  if hdr.type == 2000
    hdr.subsize = fread(fid,1,'int32', 0, hdr_endian);
    hdr.ystart = fread(fid,1,'double', 0, hdr_endian);
    hdr.ydelta = fread(fid,1,'double', 0, hdr_endian);
    hdr.yunits = fread(fid,1,'int32', 0, hdr_endian);
  end;

  hdr.hdr_endian = hdr_endian;
  hdr.data_endian = data_endian;

  fclose(fid);
  return 
  
%%%%%

function stat = getstat(hdr)

  ERROR_FMT = 0;

  if hdr.format(1) == 'S'
    elem_per_pt = 1;
    cplx = 0;
  elseif hdr.format(1) == 'C'
    elem_per_pt = 2;
    cplx = 1;
  else
    ERROR_FMT = 1;
  end;

  if hdr.format(2) == 'I'
    dtype = 'int16';
    bpa = 2;
  elseif hdr.format(2) == 'B'
    dtype = 'int8';
    bpa = 1;
  elseif hdr.format(2) == 'L'
    dtype = 'int32';
    bpa = 4;
  elseif hdr.format(2) == 'F'
    dtype = 'single';
    bpa = 4;
  elseif hdr.format(2) == 'X'
    dtype = 'int64';
    bpa = 8;
  elseif hdr.format(2) == 'D'
    dtype = 'double';
    bpa = 8;
  else
    ERROR_FMT = 1;
  end;

  if ERROR_FMT
    fprintf(1,'Unsupported data format %s.  Only scalar and complex formats supported\n');
    return;
  end;

  bpe = bpa * elem_per_pt;
  nelem = hdr.data_size / bpe;

  stat.type = hdr.type;
  if stat.type == 2000
    stat.subsize = hdr.subsize;
    stat.size = nelem / hdr.subsize;
  end;
  stat.nelem = nelem;
  stat.dtype = dtype;
  stat.bpa = bpa;
  stat.bpe = bpe;
  stat.elem_per_pt = elem_per_pt;
  stat.cplx = cplx;
  if isfield(hdr,'timecode')
    stat.timecode = format_timecode(hdr.timecode);
  end;

%%%%%

function data = readdata(file, hdr, stat, nstart, nend)

if nstart == -1,
  nstart = 0;
end;

if nend == -1
  if stat.type == 2000
    nend = stat.nelem / stat.subsize - 1;
  else
    nend = stat.nelem - 1;
  end
end;

if stat.type == 2000
  row_elems = stat.subsize;
else
  row_elems = 1;
end

firstloc = hdr.data_start + nstart * row_elems * stat.bpe;
lastloc = firstloc + (nend - nstart) * row_elems * stat.bpe;
endloc = hdr.data_start + stat.nelem * stat.bpe;
num_elem_to_read = nend - nstart + 1;

if firstloc > endloc || lastloc > endloc
  error('Invalid index range.');
end;

fid = fopen(file,'r');
fseek(fid, firstloc, 'bof');
if stat.type == 2000
  data = fread(fid, num_elem_to_read * stat.elem_per_pt * stat.subsize, stat.dtype, 0, hdr.data_endian);
else
  data = fread(fid, num_elem_to_read * stat.elem_per_pt, stat.dtype, 0, hdr.data_endian);
end
fclose(fid);

if stat.cplx
  data = data(1:2:end) + j*data(2:2:end);
end;

if stat.type == 2000
  data = reshape(data,stat.subsize,length(data)/stat.subsize).';
end;

%%%%

function tcstr = format_timecode(tc)
% tc is a double representing J1950
    tci = floor(tc);
    tcf = tc - tci;
    if isoctave()
      tci70 = tci - 631152000;  % convert J1950 to J1970
      tstruct = gmtime(tci70);  % since 1900-01-01 00:00:00
      yr = tstruct.year + 1900;
      mo = tstruct.mon + 1;  % fix off by 1 bug
      da = tstruct.mday;
      hr = tstruct.hour;
      mi = tstruct.min;
      se = tstruct.sec + tcf;
    else
      dn = tci / 86400 + datenum([1950 1 1 0 0 0]);
      dv = datevec(dn);
      yr = dv(1);
      mo = dv(2);
      da = dv(3);
      hr = dv(4);
      mi = dv(5);
      se = dv(6) + tcf;
    end;
    tcstr = sprintf('%.4d-%.2d-%.2d::%.2d:%.2d:%2.6f', ...
          yr,mo,da,hr,mi,se);

%%%%

function isOct = isoctave()
  isOct = exist('octave_config_info') > 1;

%%%%

function mfmt = get_endian(majik)
  if strcmp(majik, 'IEEE')
    mfmt = 'ieee-be';
  else
    mfmt = 'ieee-le';
  end

