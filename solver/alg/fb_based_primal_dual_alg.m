function s = fb_based_primal_dual_alg()
%FB_BASED_PRIMAL_DUAL Forward backward based primal dual algorithm
%   Usage : param.algo = fb_based_primal_dual();
%
%   This function returns a structure containing the algorithm. You can
%   lauch your personal algorithm with the following::
%
%           param.algo = fb_based_primal_dual();
%           sol = solvep(x0, {f1, f2, f3}, param);
%

    % This function returns a structure with 4 fields:
    % 1) The name of the solver. This is used to select the solvers.
    s.name = 'FB_BASED_PRIMAL_DUAL';
    % 2) A method to initialize the solver (called at the beginning)
    s.initialize = @(x_0, fg, Fp, param) ...
      fb_based_primal_dual_initialize(x_0,fg,Fp,param);
    % 3) The algorithm itself (called at each iterations)
    s.algorithm = @(x_0, fg, Fp, sol, s, param) ...
      fb_based_primal_dual_algorithm(fg, Fp, sol, s, param);
    % 4) Post process method (called at the end)
    s.finalize = @(x_0, fg, Fp, sol, s, param) sol;
    % The variables here are
    %   x_0 : The starting point
    %   fg  : A single smooth function 
    %         (if fg.beta == 0, no smooth function is specified) 
    %   Fp  : The non smooth functions (a cell array of structure)
    %   param: The structure of optional parameter
    %   s   : Intern variables or the algorithm
    %   sol : Current solution
end

function [sol, s, param] = fb_based_primal_dual_initialize(x_0,fg,Fp,param)

    % Handle optional parameter. Here we need a variable lambda.
    if ~isfield(param, 'rescale'), param.rescale = 0 ; end
    if ~isfield(param, 'nu'), param.nu = 1 ; end
    if ~isfield(param, 'method'), param.method = 'ISTA'; end
    
    if param.rescale
        error('Not implemented yet')
    end
    
    if ~(numel(Fp)==2)
        error('This solver needs 2 non-smooth functions')
    end
    s = struct;
    s.method = param.method;
    
    if isfield(Fp{1},'L')
        s.ind = [2,1];
        L = Fp{1}.L;
        Lt = Fp{1}.Lt;
    elseif isfield(Fp{2},'L')
        s.ind = [1,2];
        L = Fp{2}.L;        
        Lt = Fp{2}.Lt;        
    else
        L =@(x) x;
        Lt = @(x) x;
        s.ind = [1,2];
    end
    
    if strcmp(s.method, 'FISTA')
        s.tn = 1;
    end
    
    % computes optimal timestep
    if ~isfield(param, 'sigma') && ~isfield(param, 'tau')
        beta = fg.beta;
        s.tau = 1/beta;
        s.sigma = beta/2/param.nu;
    elseif ~isfield(param, 'tau')
        beta = fg.beta;
        s.tau = param.tau;
        s.sigma = (1/s.tau - beta/2)/param.nu;
        if s.sigma <0
            error('Tau is too big!')
        end
    elseif ~isfield(param, 'sigma')
        beta = fg.beta;
        s.sigma = param.sigma;
        s.tau = 1/(s.sigma*param.nu+beta/2);
    else
        s.tau = param.tau;
        s.sigma = param.sigma;
    end
   

    
    % All intern variables are stored into the structure s
    s.OpL = L;
    s.OpLt = Lt;
	s.x_n = {}; % Here x_n will contains pn
    s.qn = zeros(size(x_0));
    s.vn = s.OpL(x_0);
    s.prox_adjoint = @(x,T) prox_adjoint(x,T,Fp{s.ind(2)});
    % *sol* is set to the initial points
    sol = x_0;
    s.dual_var = s.vn;
    param.abs_tol = 1;
    param.use_dual = 1;
    
end

function [sol, s] = fb_based_primal_dual_algorithm(fg, Fp, sol, s, param)

	grad = fg.grad(sol);
    s.x_n{1} = Fp{s.ind(1)}.prox_ad(...
        sol - s.tau * (grad + s.OpLt(s.vn)), ...
        s.tau);
    s.qn = s.prox_adjoint( ...
        s.vn + s.sigma * s.OpL(2*s.x_n{1}{1} - sol), s.sigma);

    % updates
    if strcmp(s.method, 'FISTA')
        tn1 = (1 + sqrt(1+4*s.tn^2))/2;
        sol = sol + (s.tn-1)/tn1 * (s.x_n{1}{1} - sol);  
        s.vn = s.vn + (s.tn-1)/tn1 * (s.qn - s.vn);
        s.tn = tn1;
    elseif strcmp(s.method, 'ISTA')
        sol = sol + param.lambda * (s.x_n{1}{1} - sol); 
        s.vn = s.vn + param.lambda * (s.qn - s.vn);
    else
        error('Unknown method')
    end
    s.dual_var = s.vn;

 

end