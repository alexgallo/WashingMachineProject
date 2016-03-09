function [P, C, fail_rate] = opt_elect_sizing(D, eta_c, eta_d, J_P, J_C)
%% This function solves an optimisation problem to find the minimal battery 
% and solar panel sizes.

% It does so by letting the energy inside the batteries be a variable of
% the optimisation problem and solves for the minimal maximum value of the
% storage vector.

% See reference on linprog for details about the structure of the matrices
% that follow

%% Input arguments
% D is the daily aggregate demand in kWh 
% eta_c is the charging efficiency of the battery
% eta_d is the discharging efficiency of the battery
% J_P is the cost per kW nominal power of solar panels
% J_C is the cost per kWh nominal storage capacity of the battery

%% Output Arguments
% P is the nominal power of solar panels
% C is the needed capacity of the battery in kWh
% fail_rate is the expected number of days it will not operate in a year

%% Working variables
% S[k] is the energy inside the battery on day k
% DD is a vector containing the damand in kWh for each day of the year

%% Build cost function f
f = [J_P,J_C,zeros(1,365)]';

%% Calculate Ed and DD
% Ed is a vector containing the ratio of energy per kW nominal power
% installed for each day in a year

Ed = Ed_dist();
DD = ones(365,1).*D;

%% Build inequality constraints
% First constraint is -eta_c Ed[k] P - S[k] < -(1/eta_d)D[k], i.e. the
% demand must be less or equal to the total energy into the battery plus
% the energy already in the battery

A1 = [-eta_c.*Ed,zeros(365,1),-eye(365)];
b1 = -(1/eta_d)*DD;

% Second constraint is S[1]<S[365], i.e. the energy at the end of the year
% must be more or equal to the energy at the beginning of the year,
% otherwise we would accumulate a deficit each year.

A2 = [0,0,1,zeros(1,363),-1];
b2 = 0;

% Third Constraint is P > 0, i.e. nominal solar panel cannot be less than 0
A3=[-1,ones(1,366)];
b3=0;

% Fourth Constraint is -S<C<S, necessary to ensure that max(S) is C
A4=[zeros(365,1),-1.*ones(365,1),eye(365);
    zeros(365,1),-1.*ones(365,1),-1.*eye(365)];
b4=zeros(365,1);

% Combine Constraints into single matrices
A = [A1;A2;A3;A4];
b = [b1;b2;b3;b4];

%% Build Equality Constraint
% The equality constraint is set to ensure no energy is created or lost by
% the system, i.e. S[k] = S[k-1] + eta_c Ed[k-1] P - (1/eta_d)D

% Crop Ed to 364 elements
Ed_tilda = Ed(1:364);

% M is defined as (-1 1 0 0 ... 0 0)  (364 * 364) matrix
%                 ( 0-1 1 0 ... 0 0)
%                 ( 0 0-1 1 ... 0 0)
%                       ...
%                 ( 0 0     ...-1 1)
M = [zeros(364,1),eye(364)]-[eye(364),zeros(364,1)];

% Complete the equations
Aeq= [-eta_c.*Ed_tilda,zeros(364,1),M];
beq= -(1/eta_d).*DD;

%% Find optimal solution
x = linprog(f,A,b,Aeq,beq);

% Extract Parameters of interest
P = x(1);
C = x(2);
fail_rate = x(3:end);

end

