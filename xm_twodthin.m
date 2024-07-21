function [data, hdr] = xm_twodthin(file, Ystart, Ystride, Yend, Xstart, Xstride, Xend)
% Usage: [data, hdr] = xm_twodthin(file, Ystart, Ystride, Yend, Xstart, Xstride, Xend)
%
% Extract rectangular subset of 2-D (Type 2000) Bluefile
%
% file.........Name of Type 2000 Bluefile to read
%              Supported data types: SB,SI,SL,SX,SF,SD,CB,CI,CL,CX,CF,CD
% Ystart.......Zero-based index of first row to read
% Ystride......Increment between rows, 1 means read every row
% Yend.........Zero-based index of last row to read, -1 means read to end
% Xstart.......Zero-based index of first column to read
% Xstride......Optional increment between columns (default=1 means read very column)
% Xend.........Optional Zero-based index of last column to read, -1 means read to end
%              (default=Xstart forces read only 1 column and ignore Xstride)
% data.........Array containing rectangular subset of Bluefile data
% hdr..........Struct of Bluefile HCB information reflecting thinned dimensions
%

    if nargin < 7
        Xend = Xstart;
        Xstride = 1;
    end

    if rem(Ystart, 1) || rem(Yend, 1)
        fprintf(2,'ERROR: Ystart and Yend inputs must be integers\n');
        data = [];
        hdr = [];
        return
    end

    % Read the Type 2000 file header
    hdr = readheader(file);
    if hdr.type ~= 2000
        fprintf(2,'ERROR: Only Type 2000 files are suported.\n');
        data = [];
        hdr = [];
        return
    end

    if Ystart == 0 && Yend == 0
        data = [];
        if isfield(hdr,'timecode')
            hdr.timecode = format_timecode(hdr.timecode);
        end
    end

    % Populate internals structure
    stat = getstat(hdr);

    % Read the data
    data = readdata(file,hdr,stat,Ystart,Ystride,Yend,Xstart,Xstride,Xend);

    hdr.nelem = stat.nelem;
    if isfield(stat,'timecode')
        hdr.timecode = stat.timecode;
    end

    % Update header to reflect the thinned size (source file is not modified)
    new_sz = size(data);
    new_hdr = update_hdr(hdr,Ystart,Ystride,Xstart,Xstride,new_sz);
    hdr = new_hdr;

    hdr.size = stat.size;
    hdr = rmfield(hdr,'data_start');
    hdr = rmfield(hdr,'data_size');

end % main function

function new_hdr = update_hdr(hdr,Ystart,Ystride,Xstart,Xstride,new_sz)

    % input Ystart and Xstart use 0-based indexed addressing
    % update header fields using abscissa adressing
    new_hdr = hdr;
    new_hdr.xstart = hdr.xstart + Xstart*hdr.xdelta;
    new_hdr.ystart = hdr.ystart + Ystart*hdr.ydelta;
    new_hdr.xdelta = hdr.xdelta*Xstride;
    new_hdr.ydelta = hdr.ydelta*Ystride;
    new_hdr.subsize = new_sz(2);
    new_hdr.data_size = hdr.data_size * prod(new_sz) / hdr.nelem;
    new_hdr.nelem = prod(new_sz);

end % function

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
      end
      
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
      end

      hdr.hdr_endian = hdr_endian;
      hdr.data_endian = data_endian;

      fclose(fid);

end % function
      
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
      end

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
      end

      if ERROR_FMT
          fprintf(1,'Unsupported data format %s.  Only scalar and complex formats supported\n');
          return;
      end

      bpe = bpa * elem_per_pt;
      nelem = hdr.data_size / bpe;

      stat.type = hdr.type;
      if stat.type == 2000
          stat.subsize = hdr.subsize;
          stat.size = nelem / hdr.subsize;
      end
      stat.nelem = nelem;
      stat.dtype = dtype;
      stat.bpa = bpa;
      stat.bpe = bpe;
      stat.elem_per_pt = elem_per_pt;
      stat.cplx = cplx;
      if isfield(hdr,'timecode')
          stat.timecode = format_timecode(hdr.timecode);
      end

end % function


function data = readdata(file, hdr, stat, Ystart, Ystride, Yend, Xstart, Xstride, Xend)

    if Xstart == -1 || Xstart > stat.subsize - 1
        Xstart = stat.subsize - 1;
    end

    if Xend == -1 || Xend > stat.subsize - 1
        Xend = stat.subsize - 1;
    end

    if Yend == -1 || Yend > stat.size - 1
        Yend = stat.size - 1;
    end

    row_elems = stat.subsize;
    firstloc = hdr.data_start + Ystart * row_elems * stat.bpe;
    lastloc = firstloc + (Yend - Ystart) * row_elems * stat.bpe;
    endloc = hdr.data_start + stat.nelem * stat.bpe;
    num_elem_to_read = numel(Ystart:Ystride:Yend); %Yend - Ystart + 1;

    if firstloc > endloc || lastloc > endloc
        error('Invalid index range.');
    end

    skip = stat.subsize * stat.elem_per_pt * stat.bpa - stat.bpa;
    skip = skip + (Ystride - 1) * (stat.subsize * stat.elem_per_pt * stat.bpa);
    cols_to_read = Xstart:Xstride:Xend;

    % Initialize then read the 2d slice column by column
    data = nan(numel(Ystart:Ystride:Yend), numel(Xstart:Xstride:Xend));
    fid = fopen(file,'r');
    for kk = 1:numel(cols_to_read)

        for jj = 0:stat.cplx
            thisCol = cols_to_read(kk);
            byteOffset = thisCol * stat.elem_per_pt * stat.bpa;
            byteOffset = byteOffset + jj * stat.bpa;
            fseek(fid, firstloc + byteOffset, 'bof');
            thisDat = fread(fid, ...
                     num_elem_to_read, ...
                     stat.dtype, ...
                     skip, ...
                     hdr.data_endian);
            if jj == 0
                data(:,kk) = thisDat;
            else
                data(:,kk) = data(:,kk) + j*thisDat;
            end
        end

    end
    fclose(fid);

    if any(isnan(data(:)))
        fprintf(2,'The returned array did not get filled out as expected.\n');
    end

end % function


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
    end
    tcstr = sprintf('%.4d-%.2d-%.2d::%.2d:%.2d:%2.6f', ...
              yr,mo,da,hr,mi,se);

end % function


function isOct = isoctave()

      isOct = exist('octave_config_info') > 1;

end % function    


function mfmt = get_endian(majik)

    if strcmp(majik, 'IEEE')
        mfmt = 'ieee-be';
    else
        mfmt = 'ieee-le';
    end

end % function
