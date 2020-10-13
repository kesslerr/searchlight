function [ ]= rk_extract_VOIs_searchlight()
clear all

% the following lists must be shortened and adjusted (so if you have 4 regions, then each list has to have 4 elements ..

voinames={'rEVC','lEVC','rFFA','lFFA','rAmy','lAmy','rDLPFC','lDLPFC','ORB'}; % name of the ROIs/VOIs to be extracted/ must be similar to the names of the mask-files (without .nii extension)
voithresh=[0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05 0.05]; % statistical threshold to use for contrast
voithreshcorr={'none','none','none','none','none','none','none','none','none'}; % "none" or "FWE" correction for multiple comparisons
voicontrast=[3 3 3 3 3 3 3 3 3]; % the threshold of the contrast used to define active voxels for Singular Value Decomposition / Eigenvariate
% if you want to use the conjunction analysis use something like the following form:
%for i=3:12; voicontrast{i}=[9 10 11 12]; end

%% start SPM
% the devil is hidden in the detail... depending on if you are on the sunray system or on your private notebook, and which OS you use, you may have to adjust how to start SPM
spm('Defaults','fMRI');
spm_jobman('initcfg');

%% repeat VOI extraction for all subjects, and all ROIs

for subject=[25:900]  % subject numbers which you want to process
    
    %% change directories, if data was moved since preprocessing
	% background: SPM saves the raw file paths in the SPM.mat
	% however: sometimes you have moved files since then
	% during VOI extraction, the raw files are needed and you need to adjust the paths in the SPM file accordingly:

    oldpath='/imaging/StudyData/FOR2107/MRT_Daten/FOR2107_kontrolliert/final_MR/';
    newpath='/imaging/Kessler/MACS_DCM/0_raw_prepro_1st/';
    
	% create a string from subject number
	if subject<10
        subjects=strcat('000',num2str(subject));
    elseif subject<100
        subjects=strcat('00',num2str(subject));
    elseif subject<1000
        subjects=strcat('0',num2str(subject));
    else
        subjects=num2str(subject);
    end
    subpath=strcat(newpath,subjects,'/Hariri/1stLevel');
    try; cd(subpath); catch; continue; end

    % change paths in SPM.mat
    spm_changepath('SPM.mat',oldpath,newpath);
   
    
    %% extract all VOIs
   
    for nvoi=1:length(voinames)
        clear matlabbatch
        %% choose SPM.mat

        matlabbatch{1}.cfg_basicio.file_dir.file_ops.file_fplist.dir = {subpath};
        matlabbatch{1}.cfg_basicio.file_dir.file_ops.file_fplist.filter = '^SPM.mat$';
        matlabbatch{1}.cfg_basicio.file_dir.file_ops.file_fplist.rec = 'FPList';

        %% extract VOIs

        matlabbatch{2}.spm.util.voi.spmmat = cfg_dep('File Selector (Batch Mode): Selected Files (^SPM.mat$)', substruct('.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}, '.','val', '{}',{1}), substruct('.','files')); %{'/media/cth/TOSHIBA EXT8/MRI_data/EFP/2_firstlevel/4_mni_fieldmap_6mm/01/SPM.mat'};
        matlabbatch{2}.spm.util.voi.adjust = 4; % EOI contrast has index #4
        matlabbatch{2}.spm.util.voi.session = 1; % sesson 1
        matlabbatch{2}.spm.util.voi.name = voinames{nvoi}; % the VOI is named according to the names in the list above

        matlabbatch{2}.spm.util.voi.roi{1}.spm.spmmat = {''}; % this is only necessary if it differes from the dependency above (not sure in what situation this may be the case)
        matlabbatch{2}.spm.util.voi.roi{1}.spm.contrast = voicontrast(nvoi); % the contrast index (you can see it in the contrast manager, or by clicking "Results" in SPM), from which you want to define the voxels for SVD
        matlabbatch{2}.spm.util.voi.roi{1}.spm.conjunction = 1; % 1 = no conjunction
        matlabbatch{2}.spm.util.voi.roi{1}.spm.threshdesc = voithreshcorr{nvoi}; % correctino for multiple comparisons, defined in the list above
        matlabbatch{2}.spm.util.voi.roi{1}.spm.thresh = voithresh(nvoi); % p value level for the contrast to define active voxels
        matlabbatch{2}.spm.util.voi.roi{1}.spm.extent = 0; % may help eliminate confetti voxels --> single voxels/clusters below this threshold of co-active voxels will be eliminated
        matlabbatch{2}.spm.util.voi.roi{1}.spm.mask = struct('contrast', {}, 'thresh', {}, 'mtype', {});

        matlabbatch{2}.spm.util.voi.roi{2}.mask.image = {strcat('/imaging/Kessler/MACS_DCM/masks/',voinames{nvoi},'.nii,1')}; % path of the mask, in my case they were binary, spherical ROIs of size 8-12mm radius

        matlabbatch{2}.spm.util.voi.roi{3}.sphere.centre = [0 0 0]; % arbitrary start of the searchlight. because in the next step we move to global maximum, you dont need to change this. if you continue differently, think about changing this
        matlabbatch{2}.spm.util.voi.roi{3}.sphere.radius = 4; % this is the size of the (typically smaller) sphere, which will be centered around your most activated voxel. This small sphere defines/encompasses all voxels that will be extracted (if exceeding statistical threshold)
        matlabbatch{2}.spm.util.voi.roi{3}.sphere.move.global.spm = 1; % here you define, if you move to the global maximum with the searchlight (1=yes, because you have already masked all but your ROI)
        matlabbatch{2}.spm.util.voi.roi{3}.sphere.move.global.mask = 'i2'; % here you actually mask out everything but the ROI defined above
        matlabbatch{2}.spm.util.voi.expression = 'i1 & i3'; % your final VOI will be comprised by 2 images:
								% i1 is the thesholded SPM
								% i3 is the smaller sphere
								% i2 was the mask, which will not be used here
								


        %% run batch
		% this is the easy way, just run it. However, if you have large sample sizes,
		% you can use the code below to 1. have some kind of primitive logging of progess
		% and 2. of one subjects fails (but others not) then the procedure is not cancelled
		% as a whole (you should check logfile however afterwards)

         %spm_jobman('run',matlabbatch);
         %clear matlabbatch
        
        
        %% run SPM (with logging)
        try
            spm_jobman('run',matlabbatch);
            clear matlabbatch
            timestamp=datestr(now,'dd-mm-yyyy_HH:MM:SS');
            fid = fopen('/imaging/Kessler/MACS_DCM/VOI_succeededFiles.txt', 'a'); %'w' for write, 'a' for append
            fprintf(fid ,'%s %s %s %s %s\n', timestamp, 'subject', subjects, 'VOI', voinames{nvoi});
            fclose(fid);                                          % Closes file.            
        catch
            clear matlabbatch
            timestamp=datestr(now,'dd-mm-yyyy_HH:MM:SS');
            fid = fopen('/imaging/Kessler/MACS_DCM/VOI_failedFiles.txt', 'a');
            fprintf(fid ,'%s %s %s %s %s\n', timestamp, 'subject', subjects, 'VOI', voinames{nvoi});
            fclose(fid);                                          % Closes file.
         
            continue % Pass control to the next loop iteration
        end    
        

    end
    
end

