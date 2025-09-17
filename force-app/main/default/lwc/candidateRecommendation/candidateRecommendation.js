import { LightningElement, api, wire } from 'lwc';

import getRecommendedCandidates from '@salesforce/apex/CandidateController.getRecommendedCandidates';

export default class CandidateRecommendation extends LightningElement {
    @api cardTitle = 'Matching Candidates';
    @api projectRoleId; 

    candidates = [];
    error;

    columns = [];

    @wire(getRecommendedCandidates)
    wiredCandidates({ error, data }) {
        if (data) {
            this.candidates = data.map(candidate => ({
                candidateNameUrl: '/' + candidate.Id,
                candidateNameLabel: candidate.Name,
                resumeSummary: candidate.Resume_Summary__c,
                reasonForMatch: candidate.Reason_for_Match__c,
                matchScore: candidate.Match_Score__c,
                scoreClass: this.getScoreClass(candidate.Match_Score__c)
            }));
            this.error = undefined;
        } else if (error) {
            this.error = error;
            this.candidates = [];
        }
    }

    connectedCallback() {};
}