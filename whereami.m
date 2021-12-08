function varargout=whereami(varargin)
%WHEREAMI Automatic geolocation and "you are here!" map
%	WHEREAMI tries to locate where your computer is and produces a map of
%	illuminated relief topography from SRTM data as new figure, centered on
%	your position. The function needs an internet connection, READHGT and 
%	DEM functions both available at https://github/IPGP/mapping-matlab
%
%	WHEREAMI(HOST) tries to geolocate the host name or IPv4 address HOST.
%
%	WHEREAMI([LAT LON]) fixes the latitude LAT and longitude LON values
%	(must be a 2-element vector).
%
%	WHEREAMI(...,DLAT) fixes the latitude length DLAT (map's height) in 
%	degree (default is 1, i.e., around 111 km).
%
%	WHEREAMI(...,param1,param2,...) will use any additional arguments 
%	transmitted to the DEM function to adjust the map rendering. See DEM 
%	documentation for available options and details.
%
%	X=WHEREAMI(...) returns a structure X with fields:
%	   dlat: DLAT value
%	   host: HOST string
%	    lat: LAT value
%	    lon: LON value
%	  query: structure as returned by the geolocation request
%
%	Examples:
%	   >> whereami
%	   will make a figure centered on your present position on Earth 
%	  (guessed from you computer internet address).
%
%	   >> whereami('www.ipgp.fr')
%	   will make a figure centered on the IPGP institute in Paris, France.
%
%	   >> whereami([53.38 13.06],0.5)
%	   will make a figure centered on latitude/longitude 53.38°N / 13.06°E,
%	   which is the GFZ institute in Potsdam, Germany, with a 0.5° height.
%
%
%	Author: F. Beauducel <beauducel@ipgp.fr>
%	Created: 2013-01-05
%	Updated: 2021-12-08

if exist('readhgt','file') ~= 2 || exist('dem','file') ~= 2
	error('This function needs the READHGT and DEM functions available at https://github/IPGP/mapping-matlab')
end

X.dlat = 1;
api = 'http://ip-api.com/json/';

if nargin < 1
	X.host = '';
elseif ischar(varargin{1})
	X.host = varargin{1};
elseif isnumeric(varargin{1})
	if numel(varargin{1}) == 2
		X.lat = varargin{1}(1);
		X.lon = varargin{1}(2);
	else
		X.dlat = varargin{1}(1);
	end
end

demopt = {};	
if nargin > 1
	if isnumeric(varargin{2}) && isscalar(varargin{2})
		X.dlat = varargin{2};
		if nargin > 2
			demopt = varargin(3:end);
		end
	else
		demopt = varargin(2:end);
	end
end

% geolocation from IP
if ~isfield(X,'lat')
	url = [api X.host];
	if ~exist('webread','file') == 2
		D = webread(url);
		if ~isstruct(D) % for GNU Octave compatibility
			D = json2struct(D);
		end
	else % backward compatibility for Matlab < 2014b
		D = json2struct(urlread(url,'TimeOut',5));
	end
	X.lat = D.lat;
	X.lon = D.lon;
	X.query = D;
end

% downloads SRTM tiles
xylim = [X.lon + X.dlat*[-.5,.5]/1.5/cosd(X.lat), X.lat + X.dlat*[-.5,.5]];
DEM = readhgt(xylim([3:4,1:2]));

% plots the map
figure
dem(DEM.lon,DEM.lat,DEM.z,'latlon','legend','lake',demopt{:})
p = get(gca,'Position');
target(X.lon,X.lat)
axes('Position',[p(1),p(2)+p(4),p(3),1-p(2)-p(4)])
axis([0,1,0,1]); axis off
target(0,0)
text(0,0,'  You are here!','FontSize',20,'FontWeight','b', ...
	'VerticalAlignment','middle','HorizontalAlignment','left')
text(1,0,{'Data from SRTM/NASA, 2001  ','https://github.com/IPGP/mapping-matlab (Beauducel, 2012-2021)'}, ...
	'FontSize',6,'VerticalAlignment','m','HorizontalAlignment','r')

% makes figure's size as A4 ratio
fp = get(gcf,'Position');
set(gcf,'Position',[fp(1:3) fp(3)*sqrt(2)])

if nargout > 0
	varargout{1} = X;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function J=json2struct(json)

C = textscan(json,'%s','delimiter',',');
for n = 1:length(C{1})
	ss = textscan(regexprep(C{1}{n},'[{}]',''),'%s','Delimiter',':');
	s = ss{1};
	key = regexprep(s{1},'"','');
	if ~isempty(strfind(s{2},'"'))
		val = regexprep(s{2},'"','');
	else
		val = str2double(s{2});
	end
	J.(key) = val;
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function target(x,y)

m = 'o';
s = 8;
hold on
plot(x,y,m,'MarkerSize',s,'MarkerFaceColor',[1,0,0],'MarkerEdgeColor',.2*ones(1,3),'Linewidth',.5);
plot(x,y,m,'MarkerSize',s+2,'MarkerEdgeColor',.99*ones(1,3),'MarkerFaceColor','none');
hold off
