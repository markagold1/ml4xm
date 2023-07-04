function [data, hdr] = midas2ml5001(file, nstart, nend)
% Usage: [data, hdr] = midas2ml5001(file, nstart, nend)
%
% Simple function to read type 5001 Bluefile into Matlab workspace.
%
% file.........Name of Bluefile to read
% nstart.......Optional zero-based index of first element to read
% nend.........Optional zero-based index of last element to read
% data.........Array containing Bluefile data
% hdr..........Structure containing Bluefile HCB information
%
% This implementation supports Type 5001 files using 3 cartesian (ECEF) 
% components: POS in m, VEL in m/sec, and ACC in m/sec^2. Other formats
% are not supported.  Data is read into a 2-d array in which each
% row contains one measurement of the form:
% [POS(m) VEL(m/sec) ACC(m/sec^2)] in vector double precision float.
%

if nargin < 3, nend   = -1; end;
if nargin < 2, nstart = -1; end;

hdr = readheader(file);
stat = getstat(hdr);
data = readdata(file,hdr,stat,nstart,nend);
hdr.nelem = stat.nelem;
if isfield(stat,'timecode')
  hdr.timecode = stat.timecode;
end;
if hdr.type == 2000 || hdr.type == 5001
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
  hdr.components = 1;
  if hdr.type == 2000
    hdr.subsize = fread(fid,1,'int32', 0, hdr_endian);
    hdr.ystart = fread(fid,1,'double', 0, hdr_endian);
    hdr.ydelta = fread(fid,1,'double', 0, hdr_endian);
    hdr.yunits = fread(fid,1,'int32', 0, hdr_endian);
  elseif hdr.type == 5001
    hdr.components = fread(fid,1,'int32', 0, hdr_endian);
    hdr.t2start = fread(fid,1,'double', 0, hdr_endian);
    hdr.t2delta = fread(fid,1,'double', 0, hdr_endian);
    hdr.t2units = fread(fid,1,'int32', 0, hdr_endian);
    hdr.reclen  = fread(fid,1,'int32', 0, hdr_endian); % becomes type 5001 bpe
    for kk = 1:hdr.components
      hdr.component(kk).name = char(fread(fid,4,'char', 0, hdr_endian))';
      hdr.component(kk).format = char(fread(fid,2,'char', 0, hdr_endian))';
      hdr.component(kk).type = int8(fread(fid,1,'char', 0, hdr_endian))';
      hdr.component(kk).units = int8(fread(fid,1,'char', 0, hdr_endian))';
    end
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
  elseif hdr.format(1) == 'V'
    elem_per_pt = 3;
    cplx = 0;
  elseif hdr.format(1) == 'N'
    elem_per_pt = -1; % not known
    cplx = 0;
  else
    ERROR_FMT = 1;
  end;

  if hdr.format(2) == 'I'
    dtype = 'int16';
    bpa = 2;
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
  elseif hdr.format(2) == 'H'
    dtype = 'double';  % assumed for type 5001
    bpa = 8;
  else
    ERROR_FMT = 1;
  end;

  if ERROR_FMT
    fprintf(1,'Unsupported data format %s.  Only scalar, complex, and vector formats supported\n');
    return;
  end;

  bpe = bpa * elem_per_pt;
  nelem = hdr.data_size / bpe;

  stat.type = hdr.type;
  if stat.type == 1000
    bpe = bpa * elem_per_pt;
    nelem = hdr.data_size / bpe;
  elseif stat.type == 2000
    bpe = bpa * elem_per_pt;
    nelem = hdr.data_size / bpe;
    stat.subsize = hdr.subsize;
    stat.size = nelem / hdr.subsize;
  elseif stat.type == 5001
    bpe = hdr.reclen;
    nelem = hdr.data_size / bpe;
    stat.components = hdr.components;
    stat.size = nelem / hdr.components;
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
  nend = stat.nelem;
end;

firstloc = hdr.data_start + nstart * stat.bpe;
lastloc = firstloc + (nend - nstart) * stat.bpe;
endloc = hdr.data_start + stat.nelem * stat.bpe;
num_elem_to_read = nend - nstart;

if firstloc > endloc || lastloc > endloc
  error('Invalid index range.');
end;

fid = fopen(file,'r');
fseek(fid, firstloc, 'bof');
if stat.type == 2000
  data = fread(fid, num_elem_to_read * stat.elem_per_pt * stat.subsize, stat.dtype, 0, hdr.data_endian);
elseif stat.type == 5001
  data = fread(fid, num_elem_to_read * stat.bpe / stat.bpa, stat.dtype, 0, hdr.data_endian);
else
  data = fread(fid, num_elem_to_read * stat.elem_per_pt, stat.dtype, 0, hdr.data_endian);
end
fclose(fid);

if stat.cplx
  data = data(1:2:end) + j*data(2:2:end);
end;

if stat.type == 2000
  data = reshape(data,stat.subsize,length(data)/stat.subsize).';
elseif stat.type == 5001
  elem_per_row = stat.bpe / stat.bpa;
  num_rows = length(data) / elem_per_row;
  data = reshape(data, elem_per_row, num_rows).';
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
    sei = floor(se);
    sef = num2str(se - sei, '%.4f');
    sef = sef(2:end);
    tcstr = sprintf('%.4d-%.2d-%.2d::%02d:%02d:%02d%s', ...
          yr,mo,da,hr,mi,sei,sef);

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

