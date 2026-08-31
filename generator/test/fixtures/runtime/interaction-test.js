const frame = document.querySelector('#site');
const scenario = new URLSearchParams(window.location.search).get('scenario');

try {
  if (scenario.startsWith('short-')) {
    frame.width = '320';
    frame.height = '180';
  }
  await waitUntilReady();
  await runScenario(frame.contentDocument, frame.contentWindow, scenario);
  document.body.dataset.test = 'passed';
} catch (error) {
  document.body.dataset.test = `failed: ${error.message}`;
}

async function waitUntilReady() {
  for (let attempt = 0; attempt < 200; attempt += 1) {
    if (frame.contentDocument?.body?.dataset.ready === 'true') return;
    await delay(20);
  }
  throw new Error('site did not become ready');
}

async function runScenario(site, siteWindow, name) {
  const topicsButton = site.querySelector('[data-action="topics"]');
  const panel = site.querySelector('#topic-panel');
  const search = site.querySelector('#topic-search');
  const empty = site.querySelector('#topic-empty');
  const topicButtons = [...site.querySelectorAll('#topic-list button')];
  const visibleTopicButtons = () => topicButtons.filter((button) => !button.parentElement.hidden);
  const enterSearch = (query) => {
    search.value = query;
    search.dispatchEvent(new siteWindow.Event('input', { bubbles: true }));
  };

  if (name === 'open') {
    topicsButton.click();
    assert(!panel.hidden, 'topic menu did not open');
    return;
  }
  if (name === 'open-focus') {
    topicsButton.click();
    assert(site.activeElement === search, 'topic menu did not focus search');
    return;
  }
  if (name === 'search') {
    topicsButton.click();
    enterSearch('sLiDiNg');
    assert(visibleTopicButtons().length === 1 && visibleTopicButtons()[0].textContent.includes('Sliding Window'), 'mixed-case search did not filter labels');
    return;
  }
  if (name === 'no-results') {
    topicsButton.click();
    enterSearch('not a topic');
    assert(empty.textContent === 'No topics found', 'empty search result was not announced');
    return;
  }
  if (name === 'select-close') {
    topicsButton.click();
    topicButtons[0].click();
    assert(panel.hidden && topicsButton.getAttribute('aria-expanded') === 'false', 'topic selection did not close the menu');
    return;
  }
  if (name === 'select-focus') {
    topicsButton.click();
    topicButtons[0].click();
    assert(site.activeElement === topicsButton, 'topic selection did not return focus');
    return;
  }
  if (name === 'select-navigation') {
    const previousTransform = site.querySelector('#board').style.transform;
    siteWindow.requestAnimationFrame = (callback) => {
      callback(siteWindow.performance.now() + 500);
      return 1;
    };
    topicsButton.click();
    topicButtons[0].click();
    assert(site.querySelector('#board').style.transform !== previousTransform, 'topic selection did not move the board');
    return;
  }
  if (name === 'cancel') {
    topicsButton.click();
    topicButtons.at(-1).click();
    await delay(50);
    const viewport = site.querySelector('#viewport');
    viewport.dispatchEvent(new siteWindow.WheelEvent('wheel', { bubbles: true, cancelable: true, clientX: 100, clientY: 100, deltaY: 50 }));
    const interruptedTransform = site.querySelector('#board').style.transform;
    await delay(600);
    assert(site.querySelector('#board').style.transform === interruptedTransform, 'direct interaction did not cancel topic motion');
    return;
  }
  if (name === 'reduced-motion') {
    const previousTransform = site.querySelector('#board').style.transform;
    topicsButton.click();
    topicButtons[0].click();
    assert(site.querySelector('#board').style.transform !== previousTransform, 'reduced motion did not apply the target immediately');
    return;
  }
  if (name === 'short-scroll') {
    topicsButton.click();
    assert(siteWindow.getComputedStyle(panel).overflowY === 'auto' && panel.scrollHeight > panel.clientHeight, 'short topic menu is not scrollable');
    return;
  }
  if (name === 'short-topic') {
    topicsButton.click();
    topicButtons[0].scrollIntoView({ block: 'nearest' });
    assert(isVisibleWithin(topicButtons[0], panel), 'short topic menu cannot reveal a topic button');
    return;
  }
  if (name === 'short-empty') {
    topicsButton.click();
    enterSearch('not a topic');
    assert(isVisibleWithin(empty, panel), 'short topic menu did not reveal the empty result');
    return;
  }
  throw new Error(`unknown scenario: ${name}`);
}

function assert(condition, message) {
  if (!condition) throw new Error(message);
}

function isVisibleWithin(element, container) {
  const elementBounds = element.getBoundingClientRect();
  const containerBounds = container.getBoundingClientRect();
  return elementBounds.top >= containerBounds.top && elementBounds.bottom <= containerBounds.bottom;
}

function delay(milliseconds) {
  return new Promise((resolve) => window.setTimeout(resolve, milliseconds));
}
