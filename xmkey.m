function [hdr, keywords] = xmkey(bluefile,varargin)
% Usage: [hdr, keywords] = xmkey(bluefile,varargin)
%
% Display and modify X-Midas Bluefile keywords.
%
% [hdr,keywords] = xmkey(bluefile,function,params)
%
% xmkey(file).....................Return all keywords as a cell array
%                                 format: {{name1,value1},...{nameN,valueN}}
% xmkey(file,'List')..............Return all keywords as a cell array
%                                 same as xmkey(file)
% xmkey(file,'List',key_name).....Return all keywords matching key_name
%                                 as a cell array
%                                 key_name is a character array
% xmkey(file,'ListStruct')........Return all keywords as a structure
%                                 whose names are structure fields
% xmkey(file,'ListStruct',key_name)
%                                 Return last keyword matching key_name
%                                 as a structure
%                                 key_name is a character array
% xmkey(file,'Add',{{name1,value1},...,{nameN,valueN}})
%                                 Add specified keywords
% xmkey(file,'Delete',{name1,...,nameN})
%                                 Delete first instance of specified keywords
% xmkey(file,'Replace',{{name1,value1},..,{nameN,valueN}})
%                                 Replace first instance of specified keywords
%
% TODO: Add support for Type 3000/6000 files.
%

    narginchk(1,3);
    if nargin == 1
        cmd = 'List';
        in_keywords = {};
        in_keyname = [];
    end
    if nargin > 1
        cmd = varargin{1};
        in_keywords = {};
        in_keyname = [];
    end
    if nargin == 3
        if iscell(varargin{2})
            in_keywords = varargin{2};
            if isempty(in_keywords)
                warning('Empty keyword input. Nothing to do.');
            elseif ~iscell(in_keywords{1})
                in_keywords = {in_keywords};
            end
        else
            in_keyname = varargin{2};
        end
    end

    % 'Delete' command
    if strcmpi(cmd, 'Delete')
        C = readkeywords(bluefile);
        C = removekeywords(C, in_keywords);
        ok = wipekeywords(bluefile);
        keywords = addkeywords(bluefile,C);
    end

    % 'Replace' command
    if strcmpi(cmd, 'Replace')
        C = readkeywords(bluefile);
        C = replacekeywords(C, in_keywords);
        ok = wipekeywords(bluefile);
        keywords = addkeywords(bluefile,C);
    end

    % 'Add' command
    if strcmpi(cmd, 'Add')
        keywords = addkeywords(bluefile,in_keywords);
    end

    % 'List' and 'ListStruct' commands
    if ~isempty(strfind(upper(cmd),'LIST'))
        keywords = readkeywords(bluefile);
        if ~isempty(in_keyname)
            keywords_match = {};
            for kk = 1:numel(keywords)
                name = keywords{kk}{1};
                value = keywords{kk}{2};
                if ~isempty(regexp(name, in_keyname,'ignorecase'))
                    keywords_match{end+1} = {name, value};
                end
            end
            keywords = keywords_match;
        end
    end

    % 'ListStruct' command
    if ~isempty(strfind(upper(cmd),'STRUCT'))
        kw_struct = struct();
        for kk = 1:numel(keywords)
            name = keywords{kk}{1};
            name = strrep(name,'.','_');
            value = keywords{kk}{2};
            eval(['kw_struct.' name ' = value;']);
        end
        keywords = kw_struct;
    end

    if strcmpi(cmd, 'Delete') || strcmpi(cmd, 'Replace') || strcmpi(cmd, 'Add')
        % Zero pad total size to integer number of 512 byte blocks
        % Not in Bluefile ICD but appears to be a convention
        pad_to_512(bluefile);
    end

    % Return final header
    hdr = readheader(bluefile);
    if isfield(hdr,'mainkeywords')
       hdr = rmfield(hdr,'mainkeywords');
    end

end % function

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function hdr = readheader(bluefile)

    % Fixed header
    hdr = header_factory();
    fid = fopen(bluefile,'r');
    endian = char(fread(fid,12,'char'))';
    hdr_endian = get_endian(endian(5:8));
    data_endian = get_endian(endian(9:12));
    fseek(fid,24,'bof');
    ext_hdr_start = fread(fid,1,'int32', 0, hdr_endian);
    ext_hdr_bytes = fread(fid,1,'int32', 0, hdr_endian);
    fseek(fid,32,'bof');
    hdr.data_start = fread(fid,1,'double', 0, hdr_endian);
    hdr.data_size = fread(fid,1,'double', 0, hdr_endian);
    hdr.type = fread(fid,1,'int32', 0, hdr_endian);
    hdr.format = char(fread(fid,2,'char', 0, hdr_endian))';
    fseek(fid,56,'bof');
    timecode = fread(fid,1,'double', 0, hdr_endian);
    if timecode > 1
        hdr.timecode = format_timecode(timecode);
    else
        hdr = rmfield(hdr,'timecode');
    end
    % Main header keywords
    fseek(fid,160,'bof');
    keylength = fread(fid,1,'int32', 0, hdr_endian);
    if keylength
      hdr.mainkeywords.keylength = keylength;
      keywords = fread(fid,keylength,'char',0,hdr_endian);
      hdr.mainkeywords.keywords = char(keywords(:).');
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
    elseif hdr.type == 5001
        hdr.components = fread(fid,1,'int32', 0, hdr_endian);
        hdr.t2start = fread(fid,1,'double', 0, hdr_endian);
        hdr.t2delta = fread(fid,1,'double', 0, hdr_endian);
        hdr.t2units = fread(fid,1,'int32', 0, hdr_endian);
        hdr.reclen  = fread(fid,1,'int32', 0, hdr_endian); % type 5001 bpe
        for kk = 1:hdr.components
            hdr.component(kk).name = char(fread(fid,4,'char', 0, hdr_endian))';
            hdr.component(kk).format = char(fread(fid,2,'char', 0, hdr_endian))';
            hdr.component(kk).type = int8(fread(fid,1,'char', 0, hdr_endian))';
            hdr.component(kk).units = int8(fread(fid,1,'char', 0, hdr_endian))';
        end
    end

    hdr.hdr_endian = hdr_endian;
    hdr.data_endian = data_endian;

    % Number of elements for data type
    hdr.number_of_elements = get_number_of_elements(hdr);

    % Extended header
    if ext_hdr_bytes > 0
        hdr.ext_hdr_start = ext_hdr_start;
        hdr.ext_hdr_bytes = ext_hdr_bytes;
    else
        hdr = rmfield(hdr,'ext_hdr_start');
        hdr = rmfield(hdr,'ext_hdr_bytes');
    end

    % Remove superfluous fields
    hdr = rmfield(hdr,'data_start');
    hdr = rmfield(hdr,'data_size');
    if hdr.type < 2000 || hdr.type > 2999
        hdr = rmfield(hdr,'ystart');
        hdr = rmfield(hdr,'ydelta');
        hdr = rmfield(hdr,'yunits');
        hdr = rmfield(hdr,'subsize');
    end

    fclose(fid);

end % function

function mfmt = get_endian(majik)
  if strcmp(majik, 'IEEE')
    mfmt = 'ieee-be';
  else
    mfmt = 'ieee-le';
  end
end

function keywords = readkeywords(bluefile)

    keywords = {};

    % header control block
    hdr = readheader(bluefile);

    % Main header keywords
    if isfield(hdr,'mainkeywords')
        mkl = hdr.mainkeywords.keylength;
        mkv = strsplitnull(hdr.mainkeywords.keywords);
        for kk=1:numel(mkv)
            if numel(mkv{kk})
                key = strsplit(mkv{kk},'=');
                keywords{end+1} = key;
                %keyname = key{1};
                %keyvalue = key{2};
            end
        end
    end

    % Extended header
    if isfield(hdr,'ext_hdr_bytes') && hdr.ext_hdr_bytes > 0
        ext_hdr_bytes_remaining = hdr.ext_hdr_bytes;
        fptr = hdr.ext_hdr_start*512;
        fid = fopen(bluefile,'r');
        fseek(fid,hdr.ext_hdr_start*512,'bof');
        while ext_hdr_bytes_remaining > 0
            [key,keystruct] = read_key(fid, hdr.hdr_endian);
            keywords{end+1} = key;
            ext_hdr_bytes_remaining = ext_hdr_bytes_remaining - keystruct.lkey;
            fptr = fptr + keystruct.lkey;
            fseek(fid,fptr ,'bof');
        end
        fclose(fid);

        if ext_hdr_bytes_remaining ~= 0
            warning('Expected 0 ext bytes remaining.');
            %keyboard
        end
    end

end % function

function [keywords,ext_hdr_bytes] = addkeywords(bluefile,keywords_to_add)

    hdr = readheader(bluefile);
    keywords = readkeywords(bluefile);

    fid = fopen_rw(bluefile);
    if fid < 0
        crt_ext_hdr_bytes = hdr.ext_hdr_bytes;
        return
    end

    if isfield(hdr,'ext_hdr_start') && hdr.ext_hdr_start > 0
        % File already has an extended header block
        % Need to append to it
        crt_ext_hdr_bytes = hdr.ext_hdr_bytes;
        append_start = hdr.ext_hdr_start * 512 + hdr.ext_hdr_bytes;
    else
        % File does not have an extended header block
        % Need to create one and append it to the
        % first 512 byte boundary following the data
        crt_ext_hdr_bytes = 0;
        fseek(fid,0,'eof');
        append_start = ftell(fid);
        pad = mod(512 - mod(append_start,512),512);
        append_start = append_start + pad;
        ext_hdr_start = append_start / 512;
        if pad > 0
            fwrite(fid,zeros(pad,1),'int8');
        end
    end

    % When we reach here, append_start is pointing to the
    % place in fid to begin adding keywords
    for kk = 1:numel(keywords_to_add)
        fseek(fid,append_start,'bof');
        name = keywords_to_add{kk}{1};
        value = keywords_to_add{kk}{2};
        [keystruct,keyinfo] = make_keystruct(name,value);
        fwrite(fid,keystruct.lkey,'int32',hdr.hdr_endian);
        fwrite(fid,keystruct.lext,'int16',hdr.hdr_endian);
        fwrite(fid,keystruct.ltag,'int8',hdr.hdr_endian);
        fwrite(fid,keystruct.type,'char',hdr.hdr_endian);
        fwrite(fid,value,keyinfo.dtype,hdr.hdr_endian);
        fwrite(fid,name,'char',hdr.hdr_endian);
        fwrite(fid,zeros(keyinfo.npad),'int8');
        keywords{end+1} = keywords_to_add{kk};
        crt_ext_hdr_bytes = crt_ext_hdr_bytes + keystruct.lkey;
        append_start = append_start + keystruct.lkey;
    end
    ext_hdr_bytes = crt_ext_hdr_bytes;

    % Update extended header fields in the header control block
    if ~isfield(hdr,'ext_hdr_start')
        fseek(fid,24,'bof');
        fwrite(fid,ext_hdr_start,'int32',hdr.hdr_endian);
    end
    fseek(fid,28,'bof');
    fwrite(fid,ext_hdr_bytes,'int32',hdr.hdr_endian);
    fclose(fid);

end % function

function [keystruct,keyinfo] = make_keystruct(name,value)

    keystruct = struct('lkey',[],'lext',[],'ltag',[],'type','');
    switch class(value)
        case 'double'
            keystruct.type = 'D';
            ldata = 8;
        case 'char'
            keystruct.type = 'A';
            ldata = length(value);
        case 'int16'
            keystruct.type = 'I';
            ldata = 2;
        case 'int32'
            keystruct.type = 'L';
            ldata = 4;
        case 'int64'
            keystruct.type = 'X';
            ldata = 8;
        case 'single'
            keystruct.type = 'F';
            ldata = 4;
        case 'int8'
            keystruct.type = 'B';
            ldata = 1;
        otherwise
            error('Unexpected data type of write keyword.');
            %keyboard
    end
    keystruct.ltag = length(name);
    len = 8 + keystruct.ltag + ldata;
    pad = mod(8 - mod(len,8),8);
    keystruct.lkey = len + pad;
    keystruct.lext = keystruct.lkey - ldata;
    if mod(keystruct.lkey,8) ~= 0
        warning('Keyword size must be a multiple of 8 bytes.');
        %keyboard
    end
    keyinfo = struct();
    keyinfo.ldata = ldata;
    keyinfo.dtype = class(value);
    keyinfo.npad = pad;

end % function

function [key, keystruct] = read_key(fid, hdr_endian)

    % Read one keyname,keyvalue pair
    keystruct.lkey = fread(fid,1,'int32', 0, hdr_endian);
    keystruct.lext = fread(fid,1,'int16', 0, hdr_endian);
    keystruct.ltag = fread(fid,1,'int8', 0, hdr_endian);
    keystruct.type = char(fread(fid,1,'char', 0, hdr_endian))';
    key = {};
    switch keystruct.type
        case 'D'
            len = (keystruct.lkey - keystruct.lext) / sizeOf('double');
            data = fread(fid,len,'double', 0, hdr_endian).';
        case 'A'
            len = keystruct.lkey - keystruct.lext;
            data = char(fread(fid,len,'char', 0, hdr_endian))';
        case 'I'
            len = (keystruct.lkey - keystruct.lext) / sizeOf('int16');
            data = fread(fid,len,'int16', 0, hdr_endian).';
        case {'L','T'}
            len = (keystruct.lkey - keystruct.lext) / sizeOf('int32');
            data = fread(fid,len,'int32', 0, hdr_endian).';
        case 'X'
            len = (keystruct.lkey - keystruct.lext) / sizeOf('int64');
            data = fread(fid,len,'int64', 0, hdr_endian).';
        case 'F'
            len = (keystruct.lkey - keystruct.lext) / sizeOf('single');
            data = fread(fid,len,'single', 0, hdr_endian).';
        case 'B'
            len = (keystruct.lkey - keystruct.lext);
            data = fread(fid,len,'int8', 0, hdr_endian).';
        otherwise
            error('Unexpected data type of read keyword.');
            %keyboard
    end
    tag = char(fread(fid,keystruct.ltag,'char', 0, hdr_endian))';
    key = {tag, data};

end % function

function [keycellarray_out] = removekeywords(keycellarray, keysToRemoveC)
    for kk = 1:numel(keysToRemoveC)
        keyToRemove = keysToRemoveC{kk};
        for jj = 1:numel(keycellarray)
            if strcmpi(keycellarray{jj}{1},keyToRemove)
                keycellarray{jj} = {};
                break
            end
        end
    end
    keycellarray_out = {};
    for kk = 1:numel(keycellarray)
        if isempty(keycellarray{kk})
            continue
        end
        keycellarray_out{end+1} = keycellarray{kk};
    end
end % function

function [keycellarray_out] = replacekeywords(keycellarray, keysToReplaceC)
    for kk = 1:numel(keysToReplaceC)
        keyToReplace = keysToReplaceC{kk};
        for jj = 1:numel(keycellarray)
            if strcmpi(keycellarray{jj}{1},keyToReplace{1})
                keycellarray{jj}{2} = keyToReplace{2};
                break
            end
        end
    end
    keycellarray_out = keycellarray;
end % function

function [ok] = wipekeywords(bluefile)
    hdr = readheader(bluefile);
    if isfield(hdr,'ext_hdr_start') && hdr.ext_hdr_start > 0
        % File has an extended header block
        % Zero the ext_hdr_start & ext_hdr_bytes fields
        fid = fopen_rw(bluefile);
        if fid > 0
            fseek(fid,24,'bof');
            fwrite(fid,0,'int32',hdr.hdr_endian); % ext_hdr_start
            fwrite(fid,0,'int32',hdr.hdr_endian); % ext_hdr_bytes
            fclose(fid);
        end
    end
    ok = 1;
end % function

function npad = pad_to_512(bluefile);
    fid = fopen_rw(bluefile);
    if fid > 0
        fseek(fid,0,'eof');
        size_bytes = ftell(fid);
        npad = mod(512 - mod(size_bytes,512),512);
        if npad ~= 0
            fwrite(fid,zeros(npad,1),'int8');
        end
        fclose(fid);
    end
end % function

function number_of_elements = get_number_of_elements(hdr)

    stat = struct();
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
    elseif hdr.format(2) == 'H'
        dtype = 'double';  % assumed for type 5001
        bpa = 8;
    else
        ERROR_FMT = 1;
    end

    if ERROR_FMT
        error('Unsupported data format %s.', hdr.format(2));
    end

    if hdr.type == 2000
        bpe = bpa * elem_per_pt;
        number_of_elements = hdr.data_size / bpe / hdr.subsize;
    elseif hdr.type == 5001
        bpe = hdr.reclen;
        number_of_elements = hdr.data_size / bpe;
    else
        bpe = bpa * elem_per_pt;
        number_of_elements = hdr.data_size / bpe;
    end

end % function

function hdr = header_factory()

    hdr = struct('number_of_elements',[], ...
                 'type',[], ...
                 'format',[], ...
                 'xstart',[], ...
                 'xdelta',[], ...
                 'xunits',[], ...
                 'ystart',[], ...
                 'ydelta',[], ...
                 'yunits',[], ...
                 'subsize',[], ...
                 'hdr_endian',[], ...
                 'data_endian',[], ...
                 'timecode',[], ...
                 'ext_hdr_start',[], ...
                 'ext_hdr_bytes',[]);

end

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

end % function

function y = isoctave()
    y = exist('OCTAVE_VERSION', 'builtin') == 5;
end % function

function fid = fopen_rw(file)
    fid = fopen(file,'r+');
    if fid < 0
        wstr = sprintf('Cannot open %s for write. Check permissions.', file);
        fprintf(2,[wstr '\n']);
    end
end % function

function S = sizeOf(V)
    switch lower(V)
        case {'double', 'int64', 'uint64'}
            S = 8;
        case {'single', 'int32', 'uint32'}
            S = 4;
        case {'int16', 'uint16'}
            S = 2;
        case {'logical', 'char', 'int8', 'uint8'}
            S = 1;
        otherwise
            fprintf(2,'sizeOf: class %s not supported\n', V);
            S = nan;
    end
end % function

% Workaround for strsplit(str,'\0') bug in GNU Octave 3.8.2
function C = strsplitnull(str)
    C = {};
    dat = double(str);
    if dat(1) == 0
        C{end+1} = char([]);
    end
    if dat(end) == 0
        append = true;
    else
        append = false;
    end
    dat(end+1) = 0;
    while 1
        ix = find(dat == 0,1);
        c = char(dat(1:ix-1));
        if numel(c)
            C{end+1} = c;
        end
        if ix >= numel(dat)
            break
        end
        dat = dat(ix+1:end);
    end
    if append
        C{end+1} = char([]);
    end
end % function
