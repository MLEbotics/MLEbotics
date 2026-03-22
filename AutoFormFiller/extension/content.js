// Content script - runs in page context to interact with forms

console.log('[AutoFormFiller] Content script loaded');

chrome.runtime.onMessage.addListener((request, sender, sendResponse) => {
  try {
    if (request.action === 'getFormFields') {
      console.log('[AutoFormFiller] Extracting form fields...');
      const fields = extractFormFields();
      console.log(`[AutoFormFiller] Found ${fields.length} form fields`);
      sendResponse({fields});
    } else if (request.action === 'fillForm') {
      console.log('[AutoFormFiller] Filling form with instructions:', request.instructions);
      const filledCount = fillFormFields(request.instructions);
      console.log(`[AutoFormFiller] Filled ${filledCount} fields`);
      sendResponse({success: true, filledCount});
    }
  } catch (error) {
    console.error('[AutoFormFiller] Error:', error);
    sendResponse({success: false, error: error.message});
  }
});

function extractFormFields() {
  const fields = [];
  
  // Get all input, textarea, and select elements
  const inputs = document.querySelectorAll('input, textarea, select');
  console.log(`[AutoFormFiller] Found ${inputs.length} total form elements`);
  
  inputs.forEach((input, index) => {
    // Skip hidden elements
    if (input.offsetHeight === 0 && input.offsetWidth === 0) {
      return;
    }
    
    // Skip password, submit, button, hidden, reset, image, file fields
    const type = input.type ? input.type.toLowerCase() : '';
    if (['password', 'submit', 'button', 'hidden', 'reset', 'image', 'file', 'checkbox'].includes(type)) {
      return;
    }
    
    let label = '';
    
    // Try to find associated label
    if (input.id) {
      const labelEl = document.querySelector(`label[for="${CSS.escape(input.id)}"]`);
      if (labelEl) label = labelEl.textContent.trim().toLowerCase();
    }
    
    // Try placeholder
    if (!label && input.placeholder) {
      label = input.placeholder.toLowerCase();
    }
    
    // Try aria-label
    if (!label && input.getAttribute('aria-label')) {
      label = input.getAttribute('aria-label').toLowerCase();
    }
    
    // Try name attribute
    if (!label && input.name) {
      label = input.name.toLowerCase();
    }
    
    // Try parent label
    if (!label && input.parentElement && input.parentElement.tagName === 'LABEL') {
      label = input.parentElement.textContent.trim().toLowerCase();
    }

    // For select elements, also capture the available options
    let options = [];
    if (input.tagName === 'SELECT') {
      options = Array.from(input.options).map(o => ({ value: o.value, text: o.text.trim() }));
    }

    // For radio buttons, group by name and collect all options
    if (type === 'radio') {
      // Only process the first radio in each named group
      const groupName = input.name;
      if (!groupName || fields.some(f => f.id === groupName && f.type === 'radio')) return;
      const radioOptions = Array.from(document.querySelectorAll(`input[type="radio"][name="${CSS.escape(groupName)}"]`))
        .map(r => {
          let rLabel = '';
          if (r.id) {
            const lEl = document.querySelector(`label[for="${CSS.escape(r.id)}"]`);
            if (lEl) rLabel = lEl.textContent.trim();
          }
          if (!rLabel && r.parentElement && r.parentElement.tagName === 'LABEL') {
            rLabel = r.parentElement.textContent.trim();
          }
          return { value: r.value, text: rLabel || r.value };
        });
      // Get group label from legend or nearby label
      let groupLabel = groupName;
      const fieldset = input.closest('fieldset');
      if (fieldset) {
        const legend = fieldset.querySelector('legend');
        if (legend) groupLabel = legend.textContent.trim().toLowerCase();
      }
      fields.push({
        id: groupName,
        name: groupName,
        type: 'radio',
        label: groupLabel,
        options: radioOptions
      });
      return;
    }
    
    // Use a stable field ID: real id > name > positional fallback
    const fieldId = input.id || input.name || `field_${index}`;

    // Tag the element so fillFormFields can find it reliably
    input.setAttribute('data-autofill-id', fieldId);
    
    const field = {
      id: fieldId,
      name: input.name || '',
      type: type || 'text',
      label: label,
      placeholder: input.placeholder || '',
      ...(options.length > 0 && { options })
    };
    
    // Only add fields with meaningful labels/names
    if (label || input.name || input.id) {
      fields.push(field);
    }
  });
  
  return fields;
}

function fillFormFields(instructions) {
  let filledCount = 0;
  
  instructions.forEach(instruction => {
    if (instruction.value === null || instruction.value === undefined) return;
    
    try {
      // Check if this is a radio group first (before any element lookup)
      const radioGroup = document.querySelectorAll(`input[type="radio"][name="${CSS.escape(instruction.fieldId)}"]`);
      if (radioGroup.length > 0) {
        const val = instruction.value.toLowerCase().trim();
        let matched = false;

        // Pass 1: exact value or label match only
        radioGroup.forEach(r => {
          const rVal = r.value.toLowerCase().trim();
          const rLabel = (r.labels && r.labels[0] ? r.labels[0].textContent : '').toLowerCase().trim();
          if (rVal === val || rLabel === val) {
            r.checked = true;
            r.dispatchEvent(new Event('change', { bubbles: true }));
            r.dispatchEvent(new Event('click', { bubbles: true }));
            matched = true;
          }
        });

        // Pass 2: only if no exact match — label starts with value
        if (!matched) {
          radioGroup.forEach(r => {
            if (matched) return;
            const rVal = r.value.toLowerCase().trim();
            const rLabel = (r.labels && r.labels[0] ? r.labels[0].textContent : '').toLowerCase().trim();
            if (rLabel.startsWith(val) || val.startsWith(rVal)) {
              r.checked = true;
              r.dispatchEvent(new Event('change', { bubbles: true }));
              r.dispatchEvent(new Event('click', { bubbles: true }));
              matched = true;
            }
          });
        }
        if (matched) {
          console.log(`[AutoFormFiller] Selected radio "${instruction.fieldId}" = "${instruction.value}"`);
          filledCount++;
        }
        return;
      }

      // Find the field — prefer the data attribute tag set during extraction,
      // then fall back to id and name for robustness
      let field = document.querySelector(`[data-autofill-id="${CSS.escape(instruction.fieldId)}"]`);
      if (!field) field = document.getElementById(instruction.fieldId);
      if (!field) field = document.querySelector(`[name="${instruction.fieldId}"]`);
      
      if (field) {
        if (field.tagName === 'SELECT') {
          fillSelectField(field, instruction.value);
        } else if (field.type === 'radio') {
          // field is the first radio in the group; find the matching option
          const radios = document.querySelectorAll(`input[type="radio"][name="${CSS.escape(instruction.fieldId)}"]`);
          const val = instruction.value.toLowerCase().trim();
          let matched = false;
          radios.forEach(r => {
            const rVal = r.value.toLowerCase().trim();
            const rLabel = (r.labels && r.labels[0] ? r.labels[0].textContent : '').toLowerCase().trim();
            if (rVal === val || rLabel === val || rVal.includes(val) || val.includes(rVal)) {
              r.checked = true;
              r.dispatchEvent(new Event('change', { bubbles: true }));
              r.dispatchEvent(new Event('click', { bubbles: true }));
              matched = true;
            }
          });
          if (matched) {
            console.log(`[AutoFormFiller] Selected radio "${instruction.fieldId}" = "${instruction.value}"`);
            filledCount++;
          }
          return;
        } else {
          field.value = instruction.value;
        }
        
        // Trigger change events for frameworks that listen to changes
        field.dispatchEvent(new Event('change', { bubbles: true }));
        field.dispatchEvent(new Event('input', { bubbles: true }));
        field.dispatchEvent(new Event('blur', { bubbles: true }));
        
        console.log(`[AutoFormFiller] Filled field "${instruction.fieldId}" with "${instruction.value}"`);
        filledCount++;
      } else {
        console.warn(`[AutoFormFiller] Could not find field "${instruction.fieldId}"`);
      }
    } catch (error) {
      console.error(`[AutoFormFiller] Error filling field "${instruction.fieldId}":`, error);
    }
  });
  
  return filledCount;
}

function fillSelectField(selectEl, value) {
  const lc = v => v.toLowerCase().trim();
  const val = lc(value);

  // 1. Exact option value match
  for (const opt of selectEl.options) {
    if (lc(opt.value) === val) { selectEl.value = opt.value; return; }
  }
  // 2. Exact option text match
  for (const opt of selectEl.options) {
    if (lc(opt.text) === val) { selectEl.value = opt.value; return; }
  }
  // 3. Option text contains value, or value contains option text
  for (const opt of selectEl.options) {
    if (lc(opt.text).includes(val) || val.includes(lc(opt.text))) {
      if (opt.value) { selectEl.value = opt.value; return; }
    }
  }
  // 4. Last resort: direct assignment (may not match any option, but worth trying)
  selectEl.value = value;
}

