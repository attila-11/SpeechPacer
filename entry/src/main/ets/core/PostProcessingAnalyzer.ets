import { SessionSummary } from '../data/TranscriptStore';

export interface PostSessionAnalysis {
  effectiveSpeakingTimeMs: number;
  pauseTimeMs: number;
  fillerWordCount: number;
  fillerDensity: number;
  topFillerWords: string[];
  repetitivePhrases: string[];
  recommendations: string[];
}

export class PostProcessingAnalyzer {

  private readonly FILLER_WORDS = ['um', 'uh', 'like', 'so', 'anyway'];

  analyze(summary: SessionSummary): PostSessionAnalysis {
    const words = this.extractAnalysisWords(summary);
    const totalWords = words.length;

    let fillerCount = 0;
    let basicallyCount = 0;
    const fillerHistogram = new Map<string, number>();

    words.forEach(word => {
      if (this.FILLER_WORDS.includes(word)) {
        fillerCount++;
        fillerHistogram.set(word, (fillerHistogram.get(word) || 0) + 1);
      }
      if (word === 'basically') {
        basicallyCount++;
      }
    });

    const repetitivePhrases = this.findRepetitivePhrases(words);
    const fillerEntries = Array.from(fillerHistogram.entries())
      .sort((left, right) => right[1] - left[1]);
    const topFillerWords = fillerEntries
      .slice(0, 3)
      .map(entry => `${entry[0]} (${entry[1]})`);
    const primaryFiller = fillerEntries.length > 0 ? fillerEntries[0] : undefined;

    const recommendations: string[] = [];

    if (summary.avgWpm > 160) {
      recommendations.push("You spoke quite fast overall. Try to take deeper breaths between sentences.");
    } else if (summary.avgWpm < 95 && summary.avgWpm > 0) {
      recommendations.push("Your pace was very slow. Try to inject a bit more energy into your delivery.");
    } else {
      recommendations.push("Great overall pacing! You kept the audience engaged.");
    }

    // The Demo "Basically" Rule
    if (basicallyCount >= 2) {
      recommendations.push(`You used the word "basically" ${basicallyCount} times. Try to trust your audience's understanding and drop the filler!`);
    } else if (fillerCount > totalWords * 0.05) {
      if (primaryFiller) {
        recommendations.push(`You leaned on "${primaryFiller[0]}" ${primaryFiller[1]} times. Practice embracing silence instead of filling the gaps.`);
      } else {
        recommendations.push("You used a high number of filler words. Practice embracing silence instead of filling the gaps.");
      }
    } else if (fillerCount > 0) {
      if (primaryFiller) {
        recommendations.push(`You used ${fillerCount} filler words, mostly "${primaryFiller[0]}" (${primaryFiller[1]}x). Reducing that hesitation will make the delivery sound sharper.`);
      } else {
        recommendations.push(`You used ${fillerCount} filler words. Reducing small hesitations will make the delivery sound sharper.`);
      }
    }

    if (repetitivePhrases.length > 0) {
      recommendations.push(`You repeated the phrase "${repetitivePhrases[0]}". Try varying your wording to sound more deliberate.`);
    }

    return {
      effectiveSpeakingTimeMs: summary.durationMs,
      pauseTimeMs: 0,
      fillerWordCount: fillerCount,
      fillerDensity: totalWords > 0 ? fillerCount / totalWords : 0,
      topFillerWords: topFillerWords,
      repetitivePhrases: repetitivePhrases,
      recommendations: recommendations
    };
  }

  private extractAnalysisWords(summary: SessionSummary): string[] {
    const finalSnapshots = summary.tokenList.filter(segment => segment.isFinal);
    const spokenWords: string[] = [];
    let previousWords: string[] = [];

    finalSnapshots.forEach(segment => {
      const currentWords = segment.text
        .split(/\s+/)
        .map(word => this.normalizeWord(word))
        .filter(word => word.length > 0);
      const prefixLength = this.getCommonPrefixLength(previousWords, currentWords);

      for (let index = prefixLength; index < currentWords.length; index++) {
        spokenWords.push(currentWords[index]);
      }

      previousWords = currentWords;
    });

    if (spokenWords.length > 0) {
      return spokenWords;
    }

    return summary.transcript
      .split(/\s+/)
      .map(word => this.normalizeWord(word))
      .filter(word => word.length > 0);
  }

  private normalizeWord(word: string): string {
    const cleanWord = word.toLowerCase().replace(/[^a-z']/g, '');

    if (/^u+h+$/.test(cleanWord)) {
      return 'uh';
    }
    if (/^u+m+$/.test(cleanWord)) {
      return 'um';
    }
    if (/^e+r+m+$/.test(cleanWord)) {
      return 'erm';
    }
    if (/^h+m+$/.test(cleanWord)) {
      return 'hmm';
    }

    return cleanWord;
  }

  private getCommonPrefixLength(previousWords: string[], currentWords: string[]): number {
    const minLength = Math.min(previousWords.length, currentWords.length);
    let prefixLength = 0;

    while (prefixLength < minLength && previousWords[prefixLength] === currentWords[prefixLength]) {
      prefixLength++;
    }

    return prefixLength;
  }

  private findRepetitivePhrases(words: string[]): string[] {
    const phraseCounts = new Map<string, number>();

    for (let size = 2; size <= 3; size++) {
      for (let index = 0; index <= words.length - size; index++) {
        const phraseWords = words.slice(index, index + size);
        const phrase = phraseWords.join(' ');

        if (phraseWords.some(word => this.FILLER_WORDS.includes(word))) {
          continue;
        }

        phraseCounts.set(phrase, (phraseCounts.get(phrase) || 0) + 1);
      }
    }

    return Array.from(phraseCounts.entries())
      .filter(entry => entry[1] >= 2)
      .sort((left, right) => {
        if (right[1] !== left[1]) {
          return right[1] - left[1];
        }
        return right[0].length - left[0].length;
      })
      .slice(0, 3)
      .map(entry => entry[0]);
  }
}
