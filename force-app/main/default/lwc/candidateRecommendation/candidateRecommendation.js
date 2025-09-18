import { LightningElement, api, wire } from 'lwc';
import { getObjectInfo } from 'lightning/uiObjectInfoApi';
import { getPicklistValues } from 'lightning/uiObjectInfoApi';
import getRecommendedCandidates from '@salesforce/apex/CandidateController.getRecommendedCandidates';
import getAllSkills from '@salesforce/apex/CandidateController.getAllSkills';
import { refreshApex } from '@salesforce/apex';

import CANDIDATE_SKILL_OBJECT from '@salesforce/schema/Candidate_Skill__c';
import CANDIDATE_PROFICIENCY_FIELD from '@salesforce/schema/Candidate_Skill__c.Proficiency__c';

export default class CandidateRecommendation extends LightningElement {
    @api recordId; 
    @api cardTitle = 'Recommended Candidates';

    loading = false;
    candidates = [];
    skillsFilter = [];
    minYearsExperience = 0;
    proficiencyFilter = '';
    skillsOptions = [];
    proficiencyOptions = [];
    showFilters = false;
    error;

    columns = [
        { 
        label: 'Name', 
        fieldName: 'Candidate_Link__c', 
        type: 'url',
        initialWidth: 200,
        typeAttributes: {
            label: { fieldName: 'Name' },
            target: '_blank'
        }
    },
        { label: 'Overview', fieldName: 'Overview__c', type: 'text', wrapText: true, initialWidth: 350 }, 
        { label: 'Skills', fieldName: 'Skills__c', type: 'text', wrapText: true, initialWidth: 350 },
    ];

    // Get Picklist Values for Proficiency Filter from Candidate_Skill__c object
    @wire(getObjectInfo, { objectApiName: CANDIDATE_SKILL_OBJECT })
    objectInfo;

    @wire(getPicklistValues, { recordTypeId: '$objectInfo.data.defaultRecordTypeId', fieldApiName: CANDIDATE_PROFICIENCY_FIELD })
    wiredProficiencyPicklist({ error, data }) {
        if (data) {
            this.proficiencyOptions = [ {label: 'All', value: ''}, ...data.values ];
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.proficiencyOptions = [];
        }
    }

    // Get all Skills for Skills Filter from Apex
    @wire(getAllSkills)
    wiredSkills({ error, data }) {
        if (data) {
            this.skillsOptions = data.map(skill => ({ label: skill.Name, value: skill.Id }));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.skillsOptions = [];
        }
    }

    @wire(getRecommendedCandidates, { 
        projectRoleId: '$recordId', 
        skillFilter: '$skillsFilter', 
        minYearsExperience: '$minYearsExperience', 
        proficiencyFilter: '$proficiencyFilter' 
    })
    wiredCandidates(result) {
        console.log('Wired candidates result:', result);
        this.wiredCandidateResult = result; // save reference for refresh
        if (result.data) {
            this.loading = false;
            this.candidates = result.data;
        } else if (result.error) {
            this.error = result.error;
            this.candidates = [];
        }
    }

    connectedCallback() {};

    handleSkillsChange(event) {
        this.skillsFilter = event.detail.value;
        this.loading = true;
        refreshApex(this.wiredCandidateResult);
    }

    handleProficiencyChange(event) {
        this.proficiencyFilter = event.detail.value;
        if(this.skillsFilter.length > 0 && this.proficiencyFilter) {
            this.loading = true;
            refreshApex(this.wiredCandidateResult);
        }
    }

    handleMinYearsExperienceChange(event) {
        let value = event.detail.value;

        // Convert to integer, or null if not valid
        let parsedValue = value !== '' ? parseInt(value, 10) : null;

        if (parsedValue !== null && !isNaN(parsedValue) && this.skillsFilter.length > 0) {
            // Ensure non-negative
            this.minYearsExperience = parsedValue < 0 ? 0 : parsedValue;

            // Refresh only when valid
            this.loading = true;
            refreshApex(this.wiredCandidateResult);
        } else {
            // If field is empty, treat as "no filter"
            this.minYearsExperience = null;
        }
    }

    toggleFilters() {
        this.showFilters = !this.showFilters;
    }
}