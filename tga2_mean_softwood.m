% TGA simulation
%% initialize 

clearvars –global
clearvars

global ycoeff afac nfac ea istart g_index s_index  MW rhos0 gsp nsp  masslossrate 

load ('ranzi_pyro_kinetics_gentile2017.mat');
MW(47)=28;
ycoeff(47,:)=0;
g_index = [3 4 5 6 7 8 9 10 11 12 13 14 16 20 21 22 29 30 31 33 34 35 47];
gsp = length(g_index);
nsp = 47;
s_index = [1 2 15 17 18 19 23 24 25 26 27 28 32 36 37 38 39 40 41 42 43 44 45 46];

Mesh.Jnodes = 1; % # nodes
sample_height = 1e-2;  % [m]
Mesh.z = linspace(0,sample_height,Mesh.Jnodes);
Mesh.dz = sample_height/(Mesh.Jnodes);
Mesh.a = 1e-2^2;
Mesh.dv = Mesh.a * Mesh.dz;

yprime0 = zeros(Mesh.Jnodes*nsp+2*Mesh.Jnodes,1);
rhos0 = zeros(Mesh.Jnodes,1);
rhos_mass0 = zeros(Mesh.Jnodes,1);

% set initial composition
m0 = zeros(47,Mesh.Jnodes);

m0(1,:) = .47; % CELL
m0(17,:) = .24; % HCE
m0(24,:) = .099; % LIGH
m0(25,:) = .099; % LIGO
m0(23,:) = .099; % LIGC
m0(38,:) = 0; %TGL
m0(37,:) = 0; %CTANN
m0(39,:) = 0; %moisture

mass0 = m0.*MW; %kg
%yi0 = mass0(s_index,1)./100;
rhos_mass0 = rhos_mass0+100;

sample_mass = Mesh.a*sample_height*rhos_mass0(1);
mass0 = mass0./100*sample_mass./Mesh.Jnodes;

y0 = [mass0(:); rhos_mass0(:)];

% specify initial conditions
T0 = 300; % initial temperature
Tend = 450+273; % final temperature
dt =.01; % time step
beta = 3.5/60; % rate of temperature change (K/s) ***CHANGE TO W
nstep = fix((Tend-T0)/beta)*100;
time = 0;
t = zeros(nstep+1,1); 
yy = zeros(nstep+1,length(y0)); % soln matrix
t(1)= 0;
yy(1,:) = y0;
ye = zeros(length(t),length(g_index));
j0 = zeros(length(t),1);
mlr = zeros(length(t),1); % mass loss rate: kg/m^3
T = zeros(length(t),1); T(1) = 300;
Mg = MW(g_index)*1e-3;

options = odeset('RelTol',1.e-4,'AbsTol',1e-5, 'NonNegative', 1, 'BDF',0, 'MaxOrder',2);

%% begin iteration (time iteration)
for i=1:nstep
    tspan = [t(i) t(i)+dt];
    [t2,a] = ode113(@(t,y)yprime(time,y,Mesh,T(i)),tspan,yy(i,:),options);
    temp = a(end,:);
    temp(temp<0)=1e-30;
    mlr(i+1) = masslossrate;
    yy(i+1,:) = temp;
    T(i+1) = T(i)+ beta*dt;
    t(i+1) = t(i) + dt;    
end

%% plot
figure(1); clf
hold on;
plot(t, mlr);
xlabel('time [s]');
ylabel('mass loss rate (mlr) [kg/m^3]');
title('Mass lost wrt t TGA2 for softwood (mlr)');

% figure(2); clf
% plot(T, mlr);
% xlabel('Temperature [K]');
% ylabel('mass loss rate (mlr) [kg/m^3]');
% title('Mass lost wrt T TGA2 for softwood (mlr)');

% figure(3); clf
% plot(T, masslossrate);
% xlabel('temperature [K]');
% ylabel('mass loss rate (masslossrate) [kg/m^3]');
% title('Mass lost wrt T TGA2 for softwood (masslossrate)');
% 
% figure(4); clf
% plot(t, masslossrate);
% xlabel('time [s]');
% ylabel('mass loss rate (masslossrate) [kg/m^3]');
% title('Mass lost wrt t TGA2 for softwood (masslossrate)');

figure(5); clf
plot(t, yy);
xlabel('time [s]');
ylabel('yy');
title('t vs. yy TGA2 mean softwood');
hold off;

%% define functions

function [] = mass_lost()
    


function [dydt] = yprime(t,yy,Mesh,T)

global ycoeff afac nfac ea istart s_index g_index MW nsp masslossrate yje

    wdot_mass = zeros(nsp,Mesh.Jnodes);
    k = zeros(28,Mesh.Jnodes);
    m = zeros(nsp,Mesh.Jnodes);
    rho_s_mass = zeros(Mesh.Jnodes,1);
    drhosdt = zeros(Mesh.Jnodes,1);
    mprime = zeros(nsp,Mesh.Jnodes);
    
    
    yje = zeros(length(g_index),1);
    
    for i=1:Mesh.Jnodes
        temp=yy(nsp*(i-1)+1:nsp*(i-1)+nsp);
        temp(temp<0)=1e-30;
        m(:,i)=temp;
        m(:,i)= m(:,i)./MW;
    end
    
    yi = zeros(length(s_index),Mesh.Jnodes);
    
    rho_s_mass(:) = yy(nsp*Mesh.Jnodes+1:end);
    
    R = 8.314; % universal gas ct [kJ/kmolK]
    
    for i=1:Mesh.Jnodes
    
        yi(:,i) = m(s_index,i).*MW(s_index)./sum(m(s_index,i).*MW(s_index));
        k(:,i) = afac .*((T(i)).^nfac).* exp(-ea ./(R*T(i)));
        mprime(:,i) = ycoeff*(k(:,i).*m(istart,i)).*MW; %dmdt
        wdot_mass(:,i) = mprime(:,i)./ Mesh.dv;
    end 
  
    for i=1:Mesh.Jnodes
        drhosdt(i) = - sum(wdot_mass(g_index,i)); 
    end

    masslossrate = sum(drhosdt); % kg/s on averge?
	   
    dydt = [mprime(:); drhosdt(:)];  
end


function phi = phii(yi,rho_s_mass)
    
    global MW s_index
    
    % densities for solid phase species w/i sample (from smoldering
    % combustion [kg/m^3])
    s_density = [9.37000000000000;9.37000000000000;25;9.87000000000000;11.5000000000000;11.5000000000000;...
        11.5000000000000;12.1200000000000;5.88000000000000;3.48000000000000;3.59000000000000;...
        5.88000000000000;4;7.29000000000000;5.76000000000000;7.22000000000000;5;1.67000000000000;...
        55;0.00369448575008421;0.00580475748165167;0.00541504238833635;0.0806563778419628;...
        0.0101350128633761;0.00507436386823035;0.00579578562602859]; 

    phi = 1-sum(yi./(s_density.*MW(s_index)))*rho_s_mass;
end


function rho_sm = rhos_mass(yi,phi)

    global MW s_index
    
    % densities for solid phase species w/i sample (from smoldering
    % combustion [kg/m^3])
    s_density = [9.3745;9.3745;25;9.87000000000000;11.5050;11.5050;...
        11.5050;12.1200000000000;5.8852;3.4826;3.59000000000000;...
        5.88000000000000;4;7.29000000000000;5.76000000000000;7.22000000000000;5;1.67000000000000;...
        55;0.00369448575008421;0.00580475748165167;0.00541504238833635;0.0806563778419628;...
        0.0101350128633761;0.00507436386823035;0.00579578562602859];

    rho_sm = (1-phi)/sum(yi./(s_density.*MW(s_index)));
end