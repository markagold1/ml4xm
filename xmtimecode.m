function tc = xmtimecode(data_file, input_time)
% Usage: tc = xmtimecode(data_file, input_time)
%
% Set and/or retrieve the timecode from a Midas data file.
% XM_TIMECODE is compatible with BLUE and Platinum Midas files.
%
%   data_file.............String containing the path and name of the
%                         Midas file to set or retrieve the timecode;
%                         path is not needed if the file exists in the
%                         MATLAB path
%
%   input_time............Optional string or numeric value used to set
%                         the timecode field in the data_file header
%
%   tc....................String representation of the timecode field;
%                         YYYY:MM:DD::HH:MM:SS.[SSSSSSSSSSSS]

    global HDR_ENDIAN

    narginchk(1,2);
    if nargin == 1
        input_time = zeros(0,1);
    end

    HDR_ENDIAN = endian(data_file);
    tc = read_timecode(data_file);
    if numel(input_time)
        if ischar(input_time)
            j1950 = tcs_to_j1950(input_time);
        else
            j1950 = input_time;
        end
        ok = update_timecode(data_file,j1950);
        tc = read_timecode(data_file);
    end

end % function

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function [header_endian,data_endian] = endian(bluefile)
    fid = fopen(bluefile,'r');
    endian = char(fread(fid,12,'char'))';
    header_endian = get_endian(endian(5:8));
    data_endian = get_endian(endian(9:12));
    fclose(fid);
end % function

function tc = read_timecode(bluefile)
    global HDR_ENDIAN

    fid = fopen(bluefile,'r');
    fseek(fid,56,'bof');
    j1950 = fread(fid,1,'double', 0, HDR_ENDIAN);
    if j1950 > 1
        tc = format_timecode(j1950);
    else
        tc = 0;
    end
    fclose(fid);

end % function

function ok = update_timecode(bluefile,j1950)
    global HDR_ENDIAN

    ok = false;
    try
        fid = fopen(bluefile,'r+');
        if ~fseek(fid,56,'bof')
            ok = fwrite(fid,j1950,'double', HDR_ENDIAN);
        end
        fclose(fid);
    catch
        error('Error updating timecode field. Is the file write-able?');
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
    end;
    tcstr = sprintf('%.4d-%.2d-%.2d::%.2d:%.2d:%2.6f', ...
          yr,mo,da,hr,mi,se);

end % function

function mfmt = get_endian(majik)
  if strcmp(majik, 'IEEE')
    mfmt = 'ieee-be';
  else
    mfmt = 'ieee-le';
  end
end % function

function y = isoctave()
    y = exist('OCTAVE_VERSION', 'builtin') == 5;
end % function

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Time conversion functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

function j1950 = tcs_to_j1950(tcs)
% Usage: j1950 = tcs_to_j1950(tcs)
%
% Convert an X-Midas timecode string to J1950.
%
%   tcs........X-Midas timecode string, format YYYY-MM-DD::hh:mm:ss.ffffff
%                                           or YYYY:MM:DD::hh:mm:ss.ffffff
%
% This function depends on iso8601_to_j1950.m
%

    ts = strrep(tcs, '::', 'T');
    ts(5) = '-';
    ts(8) = '-';
    j1950 = iso8601_to_j1950(ts);

end % function

function j1950 = iso8601_to_j1950(iso8601)

    error(nargchk(1,1,nargin));

    if ~ischar(iso8601)
        error('Expecting character string for ISO8601 input');
    end

    dateVec = iso8601_to_datevec(iso8601);
    j1950 = datevec_to_j1950(dateVec);

end % function

function dateVec = iso8601_to_datevec(iso8601)

    error(nargchk(1,1,nargin));

    if ~ischar(iso8601)
        error('Expecting character string for ISO8601 input');
    end

    [nDates,nChars] = size(iso8601);
    dateVec = zeros(nDates,6);

    if nChars >= 10
        dateVec(:,1) = str2num(iso8601(:,1:4));
        dateVec(:,2) = str2num(iso8601(:,6:7));
        dateVec(:,3) = str2num(iso8601(:,9:10));

        if nChars >= 19
            dateVec(:,4) = str2num(iso8601(:,12:13));
            dateVec(:,5) = str2num(iso8601(:,15:16));
            dateVec(:,6) = str2num(iso8601(:,18:nChars));
        elseif nChars > 10
            error('Expecting ISO8601 input in yyyy-mm-ddTHH:MM:SS.FFF format');
        end
    else
        error('Expecting ISO8601 date input in yyyy-mm-dd format');
    end

end % function

function j1950 = datevec_to_j1950(dateVec)

    error(nargchk(1,1,nargin));

    nCols = size(dateVec,2);
    if ~isnumeric(dateVec) || nCols ~= 6
        error('Expecting numeric Nx6 matrix for DATEVEC input');
    end

    secondsPerDay = 86400; % 24*60*60
    wholeDate = floor(dateVec);
    fracSecs = dateVec(:,6) - wholeDate(:,6);
    j1950Ref = datenum([1950,1,1,0,0,0]);
    dateNum = datenum(wholeDate) - j1950Ref;
    j1950 = round(dateNum * secondsPerDay) + fracSecs;

end % function
