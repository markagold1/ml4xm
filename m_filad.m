function N = m_filad(file,data)
% Usage: N = m_filad(file,data)
%
% Simple function to append Matlab workspace data to type 1000 or 2000 Bluefile.
%
% file...........Name of output Bluefile
% data...........Array to be written out, 1-d vector is written to type 1000 
%                file, 2-d arrays to type 2000 where each row is one subframe
%
% Example: Generate a type 1000 Bluefile containing the 25th root length-139 
% Zadoff-Chu sequence.
%
%   zc = exp(-j*pi*25*(0:138).*(1:139)/139).';
%   N1 = ml2midas('zcfile.tmp',zc(1:100));
%   N2 = m_filad('zcfile.tmp',zc(101:end));
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

if nargin < 2
 help m_filad
 return
end

if ~exist(file)
  estr = sprintf('Cannot find file %s.\n', file);
  fprintf(1, estr);
end

hdr = readheader(file);
stat = getstat(hdr);
X.xstart = hdr.xstart;
X.xdelta = hdr.xdelta;
X.xunits = hdr.xunits;
if hdr.type == 2000
  Y.xstart = hdr.ystart;
  Y.xdelta = hdr.ydelta;
  Y.xunits = hdr.yunits;
else
  Y = [];
end
fid = fopen(file,'r+');
N = append_data(fid,data,stat);
nelem = stat.nelem + length(data(:));
stat = update_header_nelem(fid, hdr, stat, nelem);
fclose(fid);

% << End main >>

function hdr = readheader(file)

  % Fixed header
  hdr = [];
  fid = fopen(file,'r');
  fseek(fid,32,'bof');
  hdr.data_start = fread(fid,1,'double');
  hdr.data_size = fread(fid,1,'double');
  hdr.type = fread(fid,1,'int32');
  hdr.format = char(fread(fid,2,'char'))';
  fseek(fid,56,'bof');
  timecode = fread(fid,1,'double');
  if timecode > 1
    hdr.timecode = timecode;
  end;
  
  % Adjunct header
  fseek(fid,256,'bof');
  hdr.xstart = fread(fid,1,'double');
  hdr.xdelta = fread(fid,1,'double');
  hdr.xunits = fread(fid,1,'int32');
  if hdr.type == 2000
    hdr.subsize = fread(fid,1,'int32');
    hdr.ystart = fread(fid,1,'double');
    hdr.ydelta = fread(fid,1,'double');
    hdr.yunits = fread(fid,1,'int32');
  end;

  fclose(fid);
  return 
  
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

function stat = update_header_nelem(fid, hdr, stat, nelem)

  format = hdr.format;
  if format(1) == 'S'
    elem_per_pt = 1;
  else
    elem_per_pt = 2;
  end;

  if format(2) == 'I'
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

  % Update nelem
  fseek(fid,32,'bof');
  fwrite(fid,512,'double'); % data_start, offset=32, size=8
  fwrite(fid,data_size,'double'); % offset=40, size=8

  stat.data_size = data_size;
  stat.nelem = nelem;
  return

%%%%
function N = append_data(fid,data,stat)

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
  fseek(fid, 0, 'eof');
  N = fwrite(fid,d,stat.dtype);
  N = N / stat.elem_per_pt;

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

function isOct = isoctave()
  isOct = exist('octave_config_info') > 1;

