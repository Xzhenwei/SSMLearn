clearvars
close all

nTraj = 4;
indTest = [1];
indTrain = setdiff(1:nTraj, indTest);
ICRadius = 0.25;
SSMDim = 2;

nElements = 5;
kappa = 4; % cubic spring
gamma = 0; % cubic damping
[M,C,K,fnl] = build_model(kappa, gamma, nElements);
[IC, mfd, DS, SSM] = getSSMIC(M, C, K, fnl, nTraj, ICRadius, 2*SSMDim)

Minv = inv(M);
f = @(q,qdot) [zeros(DS.n-2,1); kappa*q(DS.n-1).^3; 0];

A = [zeros(DS.n), eye(DS.n);
    -Minv*K,     -Minv*C];
G = @(x) [zeros(DS.n,1);
         -Minv*f(x(1:DS.n),x(DS.n+1:2*DS.n))];
F = @(t,x) A*x + G(x);

% F = @(t,x) DS.odefun(t,x);

observable = @(x) x(10,:);
tEnd = 100;
nSamp = 15000;

% xSim = integrateTrajectories(F, observable, tEnd, nSamp, nTraj, IC);
load bernoullidata
% load bernoullidata4d
%%
overEmbed = 16;
SSMOrder = 3;

% xData = coordinates_embedding(xSim, SSMDim, 'ForceEmbedding', 1);
xData = coordinates_embedding(xSim, SSMDim, 'OverEmbedding', overEmbed);

[V, SSMFunction, mfdInfo] = IMparametrization(xData(indTrain,:), SSMDim, SSMOrder, 'c1', 100, 'c2', 0.03);
%%
yData = getProjectedTrajs(xData, V);
plotReducedCoords(yData(indTest,:));

RRMS = getRMS(xData(indTest,:), SSMFunction, V)
%%
xLifted = liftReducedTrajs(yData, SSMFunction);
plotReconstructedTrajectory(xData(indTest(1),:), xLifted(indTest(1),:), 2)
%%
plotSSMWithTrajectories(xData(indTrain,:), SSMFunction, [1,17,19], V, 50, 'SSMDimension', SSMDim)
% axis equal
view(50, 30)