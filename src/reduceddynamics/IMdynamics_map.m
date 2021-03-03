function [R,iT,N,T,Maps_info] = IMdynamics_map(Y_data,varargin)
% Identification of the reduced dynamics in k coordinates, i.e. the map
%
%                        x_{k+1} = R(x_k)
%
% via a weighted ridge regression. R(x) = W_r * phi(x) where phi is a
% k-variate polynomial from order 1 to order M. Cross-validation can be
% performed on random folds or on the trajectories.
% Upon request, the dynamics is returned via a modal 
% coordinate change, i.e.
%
%                         R = iT o N o T
%
% where iT and T are linear maps such that the linear part of N is a 
% diagonal matrix.
%
% INPUT 
% Y_data - cell array of dimension (N_traj,2) where the first column 
%          contains time instances (1 x mi each) and the second column the 
%          trajectories (k x mi each). Sampling time is assumed to be
%          constant
%  varargin = polynomial order of R
%     or
%  varargin = options list: 'field1', value1, 'field2', value2, ... . The
%             options fields and their default values are:
%    'c1' - error coefficient for slow manifolds weighting
%           (1+c1*exp(-c2*t)).^(-1), default 0
%    'c2' - error coefficient for slow manifolds weighting
%           (1+c1*exp(-c2*t)).^(-1), default 0
% 'l_vals'- regularizer values for the ridge regression, default 0
%'n_folds'- number of folds for the cross validation, default 0
%'fold_style' - either 'default' or 'traj'. The former set random folds
%               while the latter exclude 1 trajectory at time for the cross
%               validation
% 'style' -  if set to modal, returns the dynamics in modal coordinates

if rem(length(varargin),2) > 0 && length(varargin) > 1
    error('Error on input arguments. Missing or extra arguments.')
end

% Reshape of trajectories into matrices
t   = []; % time values
X   = []; % coordinates at time k
X_1 = []; % coordinates at time k + 1
ind_traj = cell(1,size(Y_data,1)); idx_end = 0;
for ii = 1:size(Y_data,1)
    t_i = Y_data{ii,1}; Q_i = Y_data{ii,2};
    t = [t t_i(1:end-1)]; X = [X Q_i(:,1:end-1)]; X_1 = [X_1 Q_i(:,2:end)];
    ind_traj{ii} = idx_end+[1:length(t_i)]; idx_end = length(t);
end
options = IMdynamics_options(nargin,varargin,ind_traj,size(X,2));
% Phase space dimension & Error Weghting
k = size(Q_i,1); L2 = (1+options.c1*exp(-options.c2*t)).^(-2);
options = setfield(options,'L2',L2);

% Construct phi and ridge regression
[phi,Expmat] = multivariate_polynomial(k,1,options.R_PolyOrd); 
[W_r,l_opt,Err] = ridgeregression(phi(X),X_1,options.L2,...
                                         options.idx_folds,options.l_vals);
R = @(x) W_r*phi(x);
R_info = assemble_struct(R,W_r,phi,Expmat,l_opt,Err);
options.l = l_opt;
% Find the change of coordinates desired
switch options.style
    case 'modal'
        % Linear transformation
        [V,~] = eig(W_r(:,1:k)); iT = @(x) V\x; T = @(y) V*y;
        T_info = assemble_struct(T,V,@(x) x,eye(k),[],[]);
        iT_info = assemble_struct(iT,inv(V),@(y) y,eye(k),[],[]);
        % Nonlinear modal dynamics coefficients
        V_M = multivariate_polynomial_lintransf(V,k,options.R_PolyOrd);
        W_n = V\W_r*V_M; N = @(y) V\(W_r*phi(V*y));
        N_info = assemble_struct(N,W_n,phi,Expmat,[],[]);
    otherwise
        T = @(x) x; iT=@(y) y; N =@(y) R(y);
        T_info = assemble_struct(@(x) x,eye(k),@(x) x,eye(k),[],[]);
        iT_info = T_info; N_info = R_info;
end
Maps_info = struct('R',R_info,'iT',iT_info,'N',N_info,'T',T_info);
end

%---------------------------Subfunctions-----------------------------------

function str_out = assemble_struct(fun,W,phi,Emat,l,Err)
str_out = struct('Map',fun,'coeff',W,'phi',phi,'exponents',Emat,...
    'l_opt',l,'CV_error',Err);
end

%- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

% Default options

function options = IMdynamics_options(nargin_o,varargin_o,idx_traj,Ndata)
options = struct('Style','default','R_PolyOrd', 1,'iT_PolyOrd',1,...
    'N_PolyOrd',1,'T_PolyOrd',1,'c1',0,'c2',0,'L2',[],...
    'n_folds',0,...
    'l_vals',0,...
    'idx_folds',[],'fold_style',[],...
    'style','default');
% Default case
if nargin_o == 2; options.R_PolyOrd = varargin_o{:};
    options.N_PolyOrd = varargin_o{:}; end
% Custom options
if nargin_o > 2
    for ii = 1:length(varargin_o)/2
        options = setfield(options,varargin_o{2*ii-1},...
            varargin_o{2*ii});
    end
    % Setup folds for crossvalidation
    if options.n_folds > 1
        if strcmp(options.fold_style,'traj') == 1
            options = setfield(options,'n_folds',length(idx_traj));
            idx_folds = idx_traj;
        else
            idx_folds = cell(options.n_folds,1);
            ind_perm = randperm(Ndata);
            fold_size = floor(Ndata/options.n_folds);
            for ii = 1:options.n_folds-1
                idx_folds{ii} = ind_perm(1+(ii-1)*fold_size:ii*fold_size);
            end
            ii = ii + 1;
            idx_folds{ii} = ind_perm(1+(ii-1)*fold_size:length(ind_perm));
        end
        options = setfield(options,'idx_folds',idx_folds);
    end
end
end

