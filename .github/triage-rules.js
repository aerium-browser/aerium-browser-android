const IDENTITY_HEADINGS = [
  'Environment',
  'Aerium version',
  'Device and Android version',
];

const NARRATIVE_HEADINGS = [
  'Description',
  'Steps to reproduce',
  'What you expected, and what happened instead',
  'What problem does this solve?',
  'What should Aerium do?',
];

const FEATURE_HEADINGS = [
  'What problem does this solve?',
  'What should Aerium do?',
];

const FEATURE_LABELS = ['enhancement', 'documentation'];

function parseSections(body) {
  const sections = new Map();
  let heading = null;
  let buffer = [];
  const flush = () => {
    if (heading !== null) {
      sections.set(heading, buffer.join('\n'));
    }
  };
  for (const line of String(body).split(/\r?\n/)) {
    const match = /^#{2,4}\s+(.+?)\s*$/.exec(line);
    if (match) {
      flush();
      heading = match[1];
      buffer = [];
    } else if (heading !== null) {
      buffer.push(line);
    }
  }
  flush();
  return sections;
}

function strip(text) {
  return String(text)
    .replace(/```[\s\S]*?```/g, ' ')
    .replace(/^\s*[-*]\s*\[[xX ]\]\s.*$/gm, ' ')
    .replace(/!\[[^\]]*\]\([^)]*\)/g, ' ')
    .replace(/<img[^>]*>/gi, ' ')
    .replace(/<\/?[a-z][^>]*>/gi, ' ')
    .replace(/https?:\/\/\S+/g, ' ')
    .replace(/^#{1,6}\s.*$/gm, ' ')
    .replace(/_No response_/g, ' ')
    .replace(/\s+/g, ' ')
    .trim();
}

function codeVolume(body) {
  return (String(body).match(/```[\s\S]*?```/g) || []).join(' ').trim().length;
}

function evaluate({ body = '', labels = [], strict = false } = {}) {
  const sections = parseSections(body);
  const names = new Set(sections.keys());

  const isFeature =
    FEATURE_HEADINGS.some((h) => names.has(h)) ||
    labels.some((l) => FEATURE_LABELS.includes(l));

  const required = isFeature
    ? NARRATIVE_HEADINGS
    : IDENTITY_HEADINGS.concat(NARRATIVE_HEADINGS);

  const blank = required.filter(
    (h) => names.has(h) && strip(sections.get(h)).length === 0,
  );
  if (blank.length > 0) {
    return { sufficient: false, reason: 'blank-required-field', blank };
  }

  const prose = strip(body).length;
  const code = codeVolume(body);

  if (code >= 120) {
    return { sufficient: true, reason: 'ok', blank: [] };
  }

  if (strict && names.size === 0) {
    return { sufficient: false, reason: 'no-template', blank: [] };
  }

  if (prose >= 60) {
    return { sufficient: true, reason: 'ok', blank: [] };
  }

  return { sufficient: false, reason: 'too-thin', blank: [] };
}

module.exports = { evaluate, parseSections, strip, codeVolume };
