import { LightningElement, api } from 'lwc';

export default class CandidateMatchTable extends LightningElement {
    @api promptOutput;
    @api cardTitle = 'Matching Candidates';
    
    candidates = [];
    error;
    
columns = [
    { 
            label: 'Candidate Name', 
            fieldName: 'candidateName', 
            type: 'url',
            typeAttributes: {
                label: 'View Candidate',
                target: '_blank'

            }
    },
    { 
        label: 'Candidate Summary', 
        fieldName: 'resumeSummary', 
        type: 'text',
        wrapText: true 
    },
    { 
        label: 'Reason for Match', 
        fieldName: 'reasonForMatch', 
        type: 'text',
        wrapText: true 
    },
    { 
        label: 'Match Score', 
        fieldName: 'matchScore', 
        type: 'number',
        sortable: true,
        cellAttributes: { 
            class: { 
                fieldName: 'scoreClass' 
            }
        }
    }
];

    connectedCallback() {
        if (this.promptOutput) {
            this.parsePromptOutput();
        }
    }

    parsePromptOutput() {
        try {
            let output = this.cleanPromptOutput(this.promptOutput);
            this.candidates = this.extractTableData(output);
        } catch (error) {
            this.error = 'Error parsing output: ' + error.message;
            console.error('Parsing error:', error);
        }
    }

    cleanPromptOutput(output) {
        if (!output) return '';
        
        let cleaned = output;
        if (cleaned.includes('{promptResponse=')) {
            cleaned = cleaned.replace(/\{promptResponse=/g, '');
            const lastBraceIndex = cleaned.lastIndexOf('}');
            if (lastBraceIndex > 0) {
                cleaned = cleaned.substring(0, lastBraceIndex);
            }
        }
        
        return cleaned.trim();
    }

extractTableData(markdown) {
    const candidates = [];
    const lines = markdown.split('\n');
    let inTable = false;
    let headerSkipped = false;

    for (let line of lines) {
        if (line.includes('| Candidate Name') || line.includes('|Candidate Name')) {
            inTable = true;
            headerSkipped = false;
            continue;
        }

        if (inTable && line.includes(':---')) {
            headerSkipped = true;
            continue;
        }

        if (inTable && headerSkipped && line.includes('|')) {
            const cells = line.split('|').filter(cell => cell.trim() !== '');
            
            if (cells.length >= 4) {
                const candidate = {
                    fullName: cells[0].trim(),
                    resumeSummary: cells[1].trim(),
                    reasonForMatch: cells[2].trim(),
                    matchScore: parseInt(cells[3].trim()) || 0
                };
                
                // Add score class for conditional formatting
                if (candidate.matchScore >= 90) {
                    candidate.scoreClass = 'slds-text-color_success';
                } else if (candidate.matchScore >= 70) {
                    candidate.scoreClass = 'slds-text-color_default';
                } else {
                    candidate.scoreClass = 'slds-text-color_weak';
                }
                
                candidates.push(candidate);
            }
        }

        if (inTable && !line.includes('|')) {
            inTable = false;
        }
    }

    return candidates;
}

extractUrl(text) {
    // Try to extract a URL from markdown link format [label](url)
    const markdownLinkMatch = text.match(/\[.*?\]\((.*?)\)/);
    if (markdownLinkMatch) {
        return markdownLinkMatch[1];
    }
    // If it's already a URL
    if (text.startsWith('http')) {
        return text;
    }
    return '#';
}
}
