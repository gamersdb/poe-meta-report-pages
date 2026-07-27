(() => {
  const isWhitespace = (node) =>
    node.nodeType === Node.TEXT_NODE && node.textContent.trim() === "";

  const contentNodes = (element) =>
    Array.from(element.childNodes).filter((node) => !isWhitespace(node));

  const isLinkOnlyItem = (item) => {
    const nodes = contentNodes(item);
    const content = nodes.length === 1 ? nodes[0] : null;

    if (!content || content.nodeType !== Node.ELEMENT_NODE) {
      return false;
    }

    if (content.tagName === "A") {
      return true;
    }

    return (
      content.tagName === "P" &&
      contentNodes(content).length === 1 &&
      contentNodes(content)[0].tagName === "A"
    );
  };

  const isMisparsedMarkdownLinkItem = (item) => {
    const nodes = contentNodes(item);

    return (
      nodes.length === 1 &&
      nodes[0].nodeType === Node.ELEMENT_NODE &&
      nodes[0].tagName === "TABLE" &&
      /\]\(https?:\/\//.test(item.textContent)
    );
  };

  const isReferenceItem = (item) =>
    item.tagName === "LI" &&
    (isLinkOnlyItem(item) || isMisparsedMarkdownLinkItem(item));

  const collapseReferenceList = (list) => {
    const items = Array.from(list.children);
    if (items.length === 0 || !items.every(isReferenceItem)) {
      return;
    }

    const details = document.createElement("details");
    details.className = "reference-links";

    const summary = document.createElement("summary");
    summary.textContent = `参考リンク（${items.length}件）`;

    list.before(details);
    details.append(summary, list);
  };

  document
    .querySelectorAll(".report-content ul")
    .forEach(collapseReferenceList);
})();
