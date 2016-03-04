% tesa_edm()    - find artefactual components automatically by using the 
%                 EDM algorithm and FastICA as advocated in 
%                 the following paper:
%
%                           Korhonen, Hernandez-Pavon et al (2011) Removal of 
%                           large muscle artifacts from transcranial magnetic
%                           stimulation-evoked EEG by independent component
%                           analysis. Med Biol Eng Compt, 49:397-407.
%                           
% 
% You must install the FastICA toolbox and include it in the Matlab path
% before using this function
% For downloading the FastICA toolbox go to:
% http://research.ics.aalto.fi/ica/fastica/code/dlcode.shtml
%
% Usage:
%   >>  EEG = tesa_edm(EEG, chanlocs);
%   >>  EEG = tesa_edm(EEG, chanlocs, compVal, Nic);
%
% Inputs:
%   EEG                - EEGLAB EEG structure
%   chanlocs           - Channel locations 
%   Nic                - [Integer] Number of independent components to look for
%                        Default = rank(EEG)-5 (to make sure the
%                        algorithm converges).
%   sf                 - Sampling Frequency in Hz
% 
% Outputs:
%   EEG                - EEGLAB EEG structure, data after removing
%                        artefactual ICs
%
% See also:
%   SAMPLE, EEGLAB 
%
% Copyright (C) 2016  Julio Cesar Hernandez Pavon, Aalto University,
% Finland, julio.hpavon@gmail.com
%
% This program is free software; you can redistribute it and/or modify
% it under the terms of the GNU General Public License as published by
% the Free Software Foundation; either version 2 of the License, or
% (at your option) any later version.
%
% This program is distributed in the hope that it will be useful,
% but WITHOUT ANY WARRANTY; without even the implied warranty of
% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
% GNU General Public License for more details.
%
% You should have received a copy of the GNU General Public License
% along with this program; if not, write to the Free Software
% Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA



function EEG = tesa_edm(EEG, chanlocs, Nic,sf);

% Preprocessing steps before running FastICA 
[EEGwhite,inMat] = tesa_edmpreprocess(EEG, Nic); 

if nargin <3;
	Nic = rank(EEGwhite)-5;
end
if isempty(Nic)
    Nic = rank(EEGwhite)-5;
end

%%  Finding IC's by ICA symmetric
cfun='tanh'; % contrast function 
EEGwhite=double(EEGwhite);
T=size(EEGwhite,2);
s=0;
Wbest=[];
Id=eye(rank(EEGwhite));
last=Nic; % 'last' is used in the choice of the best candidate, see below

[icacomp,A,W]=fastica(EEGwhite,'approach','symm','numOfIC',Nic,'g',cfun,...
                    'whiteSig',EEGwhite,'whiteMat',Id,'dewhiteMat',Id,'verbose','off'); 
    W=W';
       neg=zeros(Nic,1);
     for j=1:Nic
        sj=W(:,j)'*EEGwhite;
        neg(j)=abs(1/T*sum(log(cosh(sj)),2)-0.374567207491438);% G(t)=log(cosh(t))
     end
    [Negs,K]=sort(neg,'descend');
    W=W(:,K);
    sjj=sum(Negs(1:last));
    if sjj>s; 
       Wbest=W; 
    end
  
Sica=Wbest'*EEGwhite; %ICA time-courses
A=1/T*inMat*Sica'; % ICA topographies

% Reshapes 2D matrix to 3D matrix
S = reshape(Sica,size(Sica,1),size(EEG.data,2),size(EEG.data,3));
S=mean(S,3);

%Inspecting ICs by looking at their time-courses, topographies & 
%power spectrum

bad_IC=[]; 

 figure;
for i = 1:size(A,2)
    % Time-courses
    subplot(3,1,1); plot(EEG.times,S(i,:));grid % Specify the time scale for both timeAxis and icacomp
    title(['IC number ',int2str(i)],'Color','b');%axis([-100, 500 , -20, 20]);
    ylabel('Arbitrary Units'); xlabel('ms');   

   % Topographies
   colormap ('jet');  
   subplot(3,1,2);topoplot(A(:,i),chanlocs,'electrodes', 'off');
   title(['Component',num2str(i)]); colorbar
   
    % Power Spectrum
    subplot(3,1,3); spectopo(S(i,:),0,sf,'freqrange', [2 60]);  
                 
            button = waitforbuttonpress; 
            if button==0,  
                disp(['Component ' int2str(i) ', signal']);
            else
                disp(['Component ' int2str(i) ', artefact']);
                bad_IC=[bad_IC, i]; 
            end
           close    
end

% Correcting the data by removing artifactual components
EEG.data = inMat-A(:,bad_IC)*Sica(bad_IC,:); %Corrected data
EEG.data = reshape(EEG.data,size(EEG.data,1),size(S,2),[]); % Reshape matrix in to eeglab format

end



