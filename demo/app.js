/**
 * Smart Expense Reimbursement & Compliance Audit Workbench
 * Enterprise-grade demo following Vercel Geist design guidelines
 * Supports seamless bilingual switching (ZH / EN)
 */

// I18N Text Dictionary
const I18N = {
  zh: {
    brandTitle: "企业智能报销与合规审核工作台",
    brandBadge: "AI 决策核验版",
    ocrBtn: "智能 OCR 转文字",
    viewImageBtn: "查看票据原图",
    imageTag: "原始票据影像 · 纸质/电子凭据",
    textTag: "结构化单据明细 (OCR 已完成)",
    copyDocBtn: "复制单据文本",
    copiedDocToast: "报销单文本已复制到剪贴板，可配合智能粘贴使用",
    claimantSelectLabel: "待审核报销单列表",
    searchLabel: "按姓名核验填报",
    smartPasteHint: "支持姓名检索或剪贴板智能粘贴",
    namePlaceholder: "输入员工姓名（如：张伟、李思琪）...",
    quickSelectLabel: "快捷选择:",
    autofillBtn: "智能识别填报",
    formTitle: "报销申报明细单",
    locateEvidence: "定位凭证",
    fieldClaimant: "申报人姓名",
    fieldEmpId: "员工工号",
    fieldDept: "所属部门",
    fieldCategory: "费用类别",
    fieldAmount: "申报总金额",
    fieldDate: "费用发生日期",
    fieldInvoice: "发票号码 / 代码",
    fieldPurpose: "费用事由与商户明细",
    auditTitle: "财务合规性智能审核",
    auditVerdictLabel: "综合合规判定",
    statusPass: "审核合格 · 准予报销",
    statusReject: "审核不合格 · 驳回修改",
    statusWarn: "需补充材料 · 待复核",
    statusIdle: "待核验 · 请输入申报人姓名",
    idleHint: "在下方输入员工姓名或使用智能粘贴完成核验",
    btnFillCurrent: "填入当前单据",
    btnClear: "清空",
    btnFillByName: "根据姓名填入",
    clearedToast: "表单已清空，等待输入",
    notFoundToast: "未找到该员工报销单据",
    claimantPlaceholder: "输入申报人姓名（如：张伟、李思奇）后回车或使用智能粘贴...",
    btnApprove: "批准报销并归档",
    btnReject: "驳回并附审核意见",
    btnExport: "导出审计报告",
    approvedToast: "已批准报销申请并推送入账，正在自动流转至下一位...",
    rejectedToast: "已驳回报销申请并发送整改意见，正在自动流转至下一位...",
    exportedToast: "审计报告 JSON 已成功复制到剪贴板",
    fillToast: (name) => `已智能加载 ${name} 的报销单据并完成合规初筛`,
    ruleCategory: {
      meal: "餐费限额标准",
      hotel: "差旅住宿标准",
      commute: "夜间交通与加班核验",
      invoice: "发票税号合规性",
      budget: "预算额度与特批有效性"
    }
  },
  en: {
    brandTitle: "Smart Expense & Compliance Audit Workbench",
    brandBadge: "AI Audit Engine",
    ocrBtn: "AI OCR to Text",
    viewImageBtn: "View Original Receipt",
    imageTag: "Original Receipt Image · Scan Copy",
    textTag: "Structured Claim Details (OCR Completed)",
    copyDocBtn: "Copy Claim Text",
    copiedDocToast: "Claim text copied to clipboard for Smart Paste demo",
    claimantSelectLabel: "Pending Claim Documents",
    formTitle: "Itemized Claim Form",
    locateEvidence: "Locate Evidence",
    fieldClaimant: "Claimant Name",
    fieldEmpId: "Employee ID",
    fieldDept: "Department",
    fieldCategory: "Expense Category",
    fieldAmount: "Claimed Amount",
    fieldDate: "Expense Date Range",
    fieldInvoice: "Invoice / Receipt No.",
    fieldPurpose: "Business Purpose & Vendor",
    auditTitle: "Compliance & Audit Engine",
    auditVerdictLabel: "Overall Audit Verdict",
    statusPass: "PASSED · APPROVED FOR PAYMENT",
    statusReject: "REJECTED · POLICY VIOLATION",
    statusWarn: "PENDING DETAILS · CONDITIONAL",
    statusIdle: "PENDING INPUT · Enter Claimant Name",
    idleHint: "Enter claimant name below or paste to verify compliance",
    btnFillCurrent: "Fill Current Doc",
    btnClear: "Clear",
    btnFillByName: "Fill by Name",
    clearedToast: "Form cleared, awaiting input",
    notFoundToast: "No matching claim record found",
    claimantPlaceholder: "Enter claimant name (e.g. James Anderson, Sarah Miller) or trigger Smart Paste...",
    btnApprove: "Approve & Settle",
    btnReject: "Reject with Feedback",
    btnExport: "Export Audit Log",
    approvedToast: "Claim approved & settled. Auto-advancing to next employee...",
    rejectedToast: "Claim rejected with audit notes. Advancing to next employee...",
    exportedToast: "Audit log JSON successfully copied to clipboard",
    fillToast: (name) => `Auto-filled claim for ${name} and verified compliance`,
    ruleCategory: {
      meal: "Meal Allowance Ceiling",
      hotel: "Lodging Policy Limit",
      commute: "Late-night Commute & Overtime Verification",
      invoice: "Invoice & Tax Compliance",
      budget: "Budget Cap & Pre-approval Validity"
    }
  }
};

/// Comprehensive Dataset: Only Zhang Wei & Li Siqi (ZH), James Anderson & Sarah Miller (EN)
const EXPENSE_DATA = {
  zh: [
    {
      id: "zhangwei",
      name: "张伟",
      dept: "市场营销部",
      empId: "EMP-2024-082",
      currency: "¥",
      rawAmount: 1680.00,
      amount: "¥1,680.00",
      date: "2026-09-12 至 2026-09-13",
      category: "差旅与客户商务宴请",
      invoiceNo: "INV-20260912-8819",
      vendor: "新荣记（上海）餐饮管理有限公司 / 强生网约车 / 快印先生",
      purpose: "Q3 华东渠道合作伙伴闭门招商晚宴宴请及返程出行",
      imageSrc: "assets/receipt_zhangwei.png",
      verdict: {
        status: "reject",
        headline: "审核不合格 · 存在餐费超标及非合规夜间出行",
        summary: "单笔餐费申报 ¥1,280.00 超过商务招待人均 ¥200 上限，且未附带同行客户签到单；夜间 23:45 产生交通费，缺少有效加班申请或客户陪同报备证明。",
        rules: [
          {
            title: "餐费限额标准",
            status: "fail",
            detail: "单笔正餐 ¥1,280.00 严重超出单人招待标准 (≤¥200)，未申报用餐人数与商务清单。",
            evidenceId: "ev-meal"
          },
          {
            title: "夜间交通与加班核验",
            status: "fail",
            detail: "23:45 产生夜间网约车打车费 ¥180.00，系统未检索到对应日期的有效加班审批工单。",
            evidenceId: "ev-commute"
          },
          {
            title: "发票税号合规性",
            status: "pass",
            detail: "发票抬头与公司税号 (91310000MA1FL4GXX) 一致，税务系统核验有效。",
            evidenceId: "ev-tax"
          },
          {
            title: "物料支出合规性",
            status: "pass",
            detail: "易拉宝物料制作费 ¥220.00 符合渠道营销月度预算额度。",
            evidenceId: "ev-supplies"
          }
        ]
      },
      htmlContent: `
        <h1 class="doc-headline">华东渠道招商闭门会商务招待报销申请</h1>
        <div class="doc-metadata-bar">
          <div class="doc-metadata-item">
            <span class="meta-label">申报人:</span>
            <span class="meta-val evidence-mark" id="ev-name" data-field="name">张伟</span>
          </div>
          <div class="doc-metadata-item">
            <span class="meta-label">工号:</span>
            <span class="meta-val evidence-mark" id="ev-empid" data-field="empId">EMP-2024-082</span>
          </div>
          <div class="doc-metadata-item">
            <span class="meta-label">部门:</span>
            <span class="meta-val evidence-mark" id="ev-dept" data-field="dept">市场营销部</span>
          </div>
          <div class="doc-metadata-item">
            <span class="meta-label">申报总额:</span>
            <span class="meta-val evidence-mark" id="ev-amount" data-field="amount" style="font-weight:700; color:#d92d20;">¥1,680.00</span>
          </div>
        </div>

        <div class="doc-section-block">
          <div class="section-label">申报事由说明</div>
          <p class="doc-paragraph">
            为推进 Q3 华东核心代理商拓展，申请人于
            <span class="evidence-mark" id="ev-date" data-field="date">2026-09-12 至 2026-09-13</span>
            期间组织闭门合作交流。主要包含
            <span class="evidence-mark" id="ev-purpose" data-field="purpose">Q3 华东渠道合作伙伴闭门招商晚宴宴请及返程出行</span>。
            发票已由财务系统验证，主发票单号为
            <span class="evidence-mark" id="ev-invoice" data-field="invoiceNo">INV-20260912-8819</span>。
          </p>
        </div>

        <div class="doc-section-block">
          <div class="section-label">费用明细清单</div>
          <div class="expense-table-wrapper">
            <table class="expense-table">
              <thead>
                <tr>
                  <th>消费日期</th>
                  <th>费用类别</th>
                  <th>消费项目 / 商户</th>
                  <th>发票 / 凭据号</th>
                  <th style="text-align:right;">金额</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>2026-09-12</td>
                  <td>商务餐饮</td>
                  <td>
                    <span class="evidence-mark" id="ev-meal" data-field="purpose">新荣记外滩店 · 客户晚宴（申报未填写同行人数）</span>
                  </td>
                  <td><span class="invoice-badge">INV-20260912-8819</span></td>
                  <td class="amount-cell" style="text-align:right; color:#d92d20;">¥1,280.00</td>
                </tr>
                <tr>
                  <td>2026-09-12 23:45</td>
                  <td>市内交通</td>
                  <td>
                    <span class="evidence-mark" id="ev-commute" data-field="purpose">强生网约车 · 外滩返回浦东住所（无加班单）</span>
                  </td>
                  <td><span class="invoice-badge">REC-20260912-0042</span></td>
                  <td class="amount-cell" style="text-align:right;">¥180.00</td>
                </tr>
                <tr>
                  <td>2026-09-13</td>
                  <td>物料制作</td>
                  <td>
                    <span class="evidence-mark" id="ev-supplies" data-field="purpose">快印先生 · 会议展示易拉宝与宣传册制作</span>
                  </td>
                  <td><span class="invoice-badge">INV-20260913-3312</span></td>
                  <td class="amount-cell" style="text-align:right;">¥220.00</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="policy-note-block">
          <div class="policy-note-title">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="12" cy="12" r="10"></circle>
              <line x1="12" y1="8" x2="12" y2="12"></line>
              <line x1="12" y1="16" x2="12.01" y2="16"></line>
            </svg>
            财务制度指引提示
          </div>
          根据《企业差旅及招待报销管理制度》第 4.2 条：商务宴请人均餐费标准上限为 ¥200/人，超过部分需剔除或由部门总监特批；晚间 21:00 之后的网约车出行需附带系统核准的加班打卡凭据或业务陪同备案。
        </div>
      `
    },
    {
      id: "lisiqi",
      name: "李思奇",
      dept: "基础架构与研发部",
      empId: "EMP-2023-115",
      currency: "¥",
      rawAmount: 3850.00,
      amount: "¥3,850.00",
      date: "2026-09-08 至 2026-09-10",
      category: "研发采购与云算力扩容",
      invoiceNo: "FP-20260908-9901",
      vendor: "某某科技有限公司 / 增值税专用发票",
      purpose: "GPU 推理集群海外镜像实例算力包与开发测试外设采购",
      imageSrc: "assets/receipt_lisiqi.png",
      verdict: {
        status: "pass",
        headline: "审核合格 · 凭证与税号合规，预算充足",
        summary: "国家增值税专用发票核验真伪通过，税号完全一致；已关联经批准的研发立项采购单 (IT-REQ-2026-442)，外设补贴金额在年度配额以内。",
        rules: [
          {
            title: "发票税号合规性",
            status: "pass",
            detail: "增值税专用发票代码与 91310000MA1FL4GXX 纳税人识别号全量匹配，无二次报销记录。",
            evidenceId: "ev-tax"
          },
          {
            title: "预算额度与特批有效性",
            status: "pass",
            detail: "成功关联事前批准采购单 IT-REQ-2026-442，云资源消耗符合基础架构季度预算分配。",
            evidenceId: "ev-approval"
          },
          {
            title: "硬件外设补贴政策",
            status: "pass",
            detail: "机械键盘与4K拓展坞采购总额 ¥900.00，在员工每两年度 ¥1,200 研发硬件补贴配额内。",
            evidenceId: "ev-hardware"
          }
        ]
      },
      htmlContent: `
        <h1 class="doc-headline">GPU 算力包扩容与研发工程外设采购报销单</h1>
        <div class="doc-metadata-bar">
          <div class="doc-metadata-item">
            <span class="meta-label">申报人:</span>
            <span class="meta-val evidence-mark" id="ev-name" data-field="name">李思奇</span>
          </div>
          <div class="doc-metadata-item">
            <span class="meta-label">工号:</span>
            <span class="meta-val evidence-mark" id="ev-empid" data-field="empId">EMP-2023-115</span>
          </div>
          <div class="doc-metadata-item">
            <span class="meta-label">部门:</span>
            <span class="meta-val evidence-mark" id="ev-dept" data-field="dept">基础架构与研发部</span>
          </div>
          <div class="doc-metadata-item">
            <span class="meta-label">申报总额:</span>
            <span class="meta-val evidence-mark" id="ev-amount" data-field="amount" style="font-weight:700; color:#107538;">¥3,850.00</span>
          </div>
        </div>

        <div class="doc-section-block">
          <div class="section-label">采购与事由说明</div>
          <p class="doc-paragraph">
            用于
            <span class="evidence-mark" id="ev-purpose" data-field="purpose">GPU 推理集群海外镜像实例算力包与开发测试外设采购</span>，
            费用发生于
            <span class="evidence-mark" id="ev-date" data-field="date">2026-09-08 至 2026-09-10</span>。
            专用发票单号
            <span class="evidence-mark" id="ev-invoice" data-field="invoiceNo">FP-20260908-9901</span>，
            已事前获得技术委员会审批单号
            <span class="evidence-mark" id="ev-approval" data-field="purpose">IT-REQ-2026-442</span>。
          </p>
        </div>

        <div class="doc-section-block">
          <div class="section-label">明细清单</div>
          <div class="expense-table-wrapper">
            <table class="expense-table">
              <thead>
                <tr>
                  <th>采购日期</th>
                  <th>科目类别</th>
                  <th>项目描述</th>
                  <th>发票类型 / 号码</th>
                  <th style="text-align:right;">金额</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>2026-09-08</td>
                  <td>云基础设施</td>
                  <td>
                    <span class="evidence-mark" id="ev-cloud" data-field="purpose">GPU 弹性算力按量资源包（含海外测试网络专线）</span>
                  </td>
                  <td><span class="invoice-badge">增值税专用 FP-20260908-9901</span></td>
                  <td class="amount-cell" style="text-align:right;">¥2,950.00</td>
                </tr>
                <tr>
                  <td>2026-09-10</td>
                  <td>研发硬件</td>
                  <td>
                    <span class="evidence-mark" id="ev-hardware" data-field="purpose">开发外接拓展坞与工学键盘（研发补贴范围）</span>
                  </td>
                  <td><span class="invoice-badge">电子发票 FP-20260910-6623</span></td>
                  <td class="amount-cell" style="text-align:right;">¥900.00</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      `
    }
  ],

  en: [
    {
      id: "james",
      name: "James Anderson",
      dept: "Global Marketing & Alliances",
      empId: "EMP-US-2024-041",
      currency: "$",
      rawAmount: 420.00,
      amount: "$420.00",
      date: "Sep 12 – Sep 13, 2026",
      category: "Client Hospitality & Travel",
      invoiceNo: "INV-NYC-2026-8819",
      vendor: "The Capital Grille, Manhattan / Uber Black / Midtown Print Co.",
      purpose: "Q3 Tri-State Enterprise Partner Dinner & Executive Travel in New York",
      imageSrc: "assets/receipt_james.png",
      verdict: {
        status: "reject",
        headline: "REJECTED · Meal Policy Ceiling & Missing Ride Logs",
        summary: "Manhattan partner dinner claim of $320.00 exceeds the $50/person per-diem policy limit with no itemized attendee log. The 11:45 PM Uber Black ride has no corresponding overtime authorization on record.",
        rules: [
          {
            title: "Meal Allowance Ceiling",
            status: "fail",
            detail: "Dinner bill of $320.00 at The Capital Grille exceeds per-person limit ($50.00 max). Missing attendee roster.",
            evidenceId: "ev-meal"
          },
          {
            title: "Late-night Commute & Overtime Verification",
            status: "fail",
            detail: "11:45 PM ride of $45.00 has no matching approved overtime ticket in HR records.",
            evidenceId: "ev-commute"
          },
          {
            title: "Invoice & Tax Compliance",
            status: "pass",
            detail: "US federal tax identification (EIN 12-3456789) verified valid with no duplicate claims.",
            evidenceId: "ev-tax"
          },
          {
            title: "Marketing Materials Budget",
            status: "pass",
            detail: "Summit roll-up banner printing ($55.00) sits within allocated regional marketing budget.",
            evidenceId: "ev-supplies"
          }
        ]
      },
      htmlContent: `
        <h1 class="doc-headline">Tri-State Enterprise Partner Dinner & Executive Travel Claim</h1>
        <div class="doc-metadata-bar">
          <div class="doc-metadata-item">
            <span class="meta-label">Claimant:</span>
            <span class="meta-val evidence-mark" id="ev-name" data-field="name">James Anderson</span>
          </div>
          <div class="doc-metadata-item">
            <span class="meta-label">ID:</span>
            <span class="meta-val evidence-mark" id="ev-empid" data-field="empId">EMP-US-2024-041</span>
          </div>
          <div class="doc-metadata-item">
            <span class="meta-label">Dept:</span>
            <span class="meta-val evidence-mark" id="ev-dept" data-field="dept">Global Marketing & Alliances</span>
          </div>
          <div class="doc-metadata-item">
            <span class="meta-label">Location:</span>
            <span class="meta-val">📍 New York, United States 🇺🇸</span>
          </div>
          <div class="doc-metadata-item">
            <span class="meta-label">Total Amount:</span>
            <span class="meta-val evidence-mark" id="ev-amount" data-field="amount" style="font-weight:700; color:#d92d20;">$420.00</span>
          </div>
        </div>

        <div class="doc-section-block">
          <div class="section-label">Business Purpose</div>
          <p class="doc-paragraph">
            Submitted for
            <span class="evidence-mark" id="ev-purpose" data-field="purpose">Q3 Tri-State Enterprise Partner Dinner & Executive Travel in New York</span>
            between
            <span class="evidence-mark" id="ev-date" data-field="date">Sep 12 – Sep 13, 2026</span>.
            Primary invoice reference:
            <span class="evidence-mark" id="ev-invoice" data-field="invoiceNo">INV-NYC-2026-8819</span>.
          </p>
        </div>

        <div class="doc-section-block">
          <div class="section-label">Itemized Expenses</div>
          <div class="expense-table-wrapper">
            <table class="expense-table">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Category</th>
                  <th>Item / Merchant</th>
                  <th>Receipt No.</th>
                  <th style="text-align:right;">Amount</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>Sep 12, 2026</td>
                  <td>Client Hospitality</td>
                  <td>
                    <span class="evidence-mark" id="ev-meal" data-field="purpose">The Capital Grille, Manhattan · Partner Dinner (Missing attendee roster)</span>
                  </td>
                  <td><span class="invoice-badge">INV-NYC-2026-8819</span></td>
                  <td class="amount-cell" style="text-align:right; color:#d92d20;">$320.00</td>
                </tr>
                <tr>
                  <td>Sep 12 23:45</td>
                  <td>Local Transit</td>
                  <td>
                    <span class="evidence-mark" id="ev-commute" data-field="purpose">Uber Black · Return from Midtown venue (No overtime form attached)</span>
                  </td>
                  <td><span class="invoice-badge">REC-UBER-0042</span></td>
                  <td class="amount-cell" style="text-align:right;">$45.00</td>
                </tr>
                <tr>
                  <td>Sep 13, 2026</td>
                  <td>Marketing Material</td>
                  <td>
                    <span class="evidence-mark" id="ev-supplies" data-field="purpose">Midtown Print Co. · Summit Display Banners & Agenda Booklets</span>
                  </td>
                  <td><span class="invoice-badge">INV-MIDTOWN-3312</span></td>
                  <td class="amount-cell" style="text-align:right;">$55.00</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>

        <div class="policy-note-block">
          <div class="policy-note-title">
            <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <circle cx="12" cy="12" r="10"></circle>
              <line x1="12" y1="8" x2="12" y2="12"></line>
              <line x1="12" y1="16" x2="12.01" y2="16"></line>
            </svg>
            Corporate Expense Policy Guidelines
          </div>
          US Travel & Entertainment Policy Sec. 4.2: Maximum client dinner allowance is $50.00 per attendee. Claims exceeding ceiling require VP approval and an attached roster. Late night rides past 10:00 PM require manager-certified overtime logs.
        </div>
      `
    },
    {
      id: "sarah",
      name: "Sarah Miller",
      dept: "Cloud Infrastructure & AI Platform",
      empId: "EMP-US-2023-115",
      currency: "$",
      rawAmount: 960.00,
      amount: "$960.00",
      date: "Sep 08 – Sep 10, 2026",
      category: "Cloud Compute & Dev Hardware",
      invoiceNo: "AWS-INV-2026-9901",
      vendor: "Amazon Web Services LLC / Apple Union Square",
      purpose: "GPU Compute Elastic Instance Quota & Thunderbolt 4 Engineering Dock",
      imageSrc: "assets/receipt_sarah.png",
      verdict: {
        status: "pass",
        headline: "PASSED · Verified Commercial Tax Invoice & Approved Requisition",
        summary: "AWS enterprise tax invoice verified authentic with EIN 12-3456789. Successfully matched against pre-approved procurement requisition IT-REQ-2026-442. Hardware subsidy falls within annual engineering allowance.",
        rules: [
          {
            title: "Invoice & Tax Compliance",
            status: "pass",
            detail: "Federal EIN 12-3456789 matched corporate register with zero duplicate claims.",
            evidenceId: "ev-tax"
          },
          {
            title: "Budget Cap & Pre-approval Validity",
            status: "pass",
            detail: "Linked to approved procurement ticket IT-REQ-2026-442. Cloud compute spend aligns with Q3 infra budget.",
            evidenceId: "ev-approval"
          },
          {
            title: "Hardware Allowance Limit",
            status: "pass",
            detail: "Thunderbolt 4 dock ($220.00) sits within the $300 biennial developer peripheral allowance.",
            evidenceId: "ev-hardware"
          }
        ]
      },
      htmlContent: `
        <h1 class="doc-headline">GPU Compute Capacity Expansion & Engineering Peripherals Claim</h1>
        <div class="doc-metadata-bar">
          <div class="doc-metadata-item">
            <span class="meta-label">Claimant:</span>
            <span class="meta-val evidence-mark" id="ev-name" data-field="name">Sarah Miller</span>
          </div>
          <div class="doc-metadata-item">
            <span class="meta-label">ID:</span>
            <span class="meta-val evidence-mark" id="ev-empid" data-field="empId">EMP-US-2023-115</span>
          </div>
          <div class="doc-metadata-item">
            <span class="meta-label">Dept:</span>
            <span class="meta-val evidence-mark" id="ev-dept" data-field="dept">Cloud Infrastructure & AI Platform</span>
          </div>
          <div class="doc-metadata-item">
            <span class="meta-label">Location:</span>
            <span class="meta-val">📍 San Francisco, CA, United States 🇺🇸</span>
          </div>
          <div class="doc-metadata-item">
            <span class="meta-label">Total Amount:</span>
            <span class="meta-val evidence-mark" id="ev-amount" data-field="amount" style="font-weight:700; color:#107538;">$960.00</span>
          </div>
        </div>

        <div class="doc-section-block">
          <div class="section-label">Business Purpose</div>
          <p class="doc-paragraph">
            Expenditure for
            <span class="evidence-mark" id="ev-purpose" data-field="purpose">GPU Compute Elastic Instance Quota & Thunderbolt 4 Engineering Dock</span>
            between
            <span class="evidence-mark" id="ev-date" data-field="date">Sep 08 – Sep 10, 2026</span>.
            Main tax invoice
            <span class="evidence-mark" id="ev-invoice" data-field="invoiceNo">AWS-INV-2026-9901</span>
            authorized under engineering requisition
            <span class="evidence-mark" id="ev-approval" data-field="purpose">IT-REQ-2026-442</span>.
          </p>
        </div>

        <div class="doc-section-block">
          <div class="section-label">Itemized Expenses</div>
          <div class="expense-table-wrapper">
            <table class="expense-table">
              <thead>
                <tr>
                  <th>Date</th>
                  <th>Category</th>
                  <th>Description</th>
                  <th>Invoice No.</th>
                  <th style="text-align:right;">Amount</th>
                </tr>
              </thead>
              <tbody>
                <tr>
                  <td>Sep 08, 2026</td>
                  <td>Cloud Infrastructure</td>
                  <td>
                    <span class="evidence-mark" id="ev-cloud" data-field="purpose">AWS GPU P5 On-demand Cluster Compute & Elastic IP Transit</span>
                  </td>
                  <td><span class="invoice-badge">AWS-INV-2026-9901</span></td>
                  <td class="amount-cell" style="text-align:right;">$740.00</td>
                </tr>
                <tr>
                  <td>Sep 10, 2026</td>
                  <td>Dev Hardware</td>
                  <td>
                    <span class="evidence-mark" id="ev-hardware" data-field="purpose">CalDigit Thunderbolt 4 Pro Dock (Apple Store Union Square)</span>
                  </td>
                  <td><span class="invoice-badge">APL-INV-2026-6623</span></td>
                  <td class="amount-cell" style="text-align:right;">$220.00</td>
                </tr>
              </tbody>
            </table>
          </div>
        </div>
      `
    }
  ]
};

// Global App State
let currentLang = 'zh';
let currentViewEmployee = null;
let currentFilledEmployee = null;
let currentTypingTimer = null;

// DOM Elements
const docViewer = document.getElementById('expenseDocViewer');
const employeeTabs = document.getElementById('employeeTabs');
const verdictCard = document.getElementById('verdictCard');
const toastContainer = document.getElementById('toastContainer');

// Form Input Elements
const formInputs = {
  claimant: document.getElementById('inputClaimant'),
  empId: document.getElementById('inputEmpId'),
  dept: document.getElementById('inputDept'),
  category: document.getElementById('inputCategory'),
  amount: document.getElementById('inputAmount'),
  date: document.getElementById('inputDate'),
  invoiceNo: document.getElementById('inputInvoiceNo'),
  purpose: document.getElementById('inputPurpose')
};

// Initialization
function init() {
  const urlParams = new URLSearchParams(window.location.search);
  const langParam = urlParams.get('lang');
  const htmlLang = document.documentElement.getAttribute('lang');

  if (langParam === 'en' || htmlLang === 'en') {
    currentLang = 'en';
  } else {
    currentLang = 'zh';
  }

  updateStaticI18nLabels();
  renderEmployeeTabs();

  // Load first employee document into left pane, and prepare form with ONLY claimant name
  const list = EXPENSE_DATA[currentLang];
  if (list && list[0]) {
    selectEmployee(list[0].id, false);
    prepareEmployeeForm(list[0]);
  }

  bindEvents();
}

// Switch Language
function setLanguage(lang) {
  if (currentLang === lang) return;
  currentLang = lang;

  document.documentElement.setAttribute('lang', lang);
  updateStaticI18nLabels();
  renderEmployeeTabs();

  // Re-select first employee on left with prepared form
  const list = EXPENSE_DATA[currentLang];
  if (list && list[0]) {
    selectEmployee(list[0].id, false);
    prepareEmployeeForm(list[0]);
  }
}

// Update UI Static Labels
function updateStaticI18nLabels() {
  const t = I18N[currentLang];
  document.querySelectorAll('[data-i18n]').forEach(el => {
    const key = el.getAttribute('data-i18n');
    if (t[key]) {
      el.textContent = t[key];
    }
  });

  if (formInputs.claimant) {
    formInputs.claimant.placeholder = t.claimantPlaceholder;
  }

  // Update active state of lang buttons
  document.querySelectorAll('.lang-btn').forEach(btn => {
    const btnLang = btn.getAttribute('data-lang');
    if (btnLang === currentLang) {
      btn.classList.add('active');
    } else {
      btn.classList.remove('active');
    }
  });
}

// Render Top Employee Switcher Tabs
function renderEmployeeTabs() {
  const list = EXPENSE_DATA[currentLang];
  employeeTabs.innerHTML = '';

  list.forEach((emp, idx) => {
    const tab = document.createElement('div');
    tab.className = 'emp-tab-chip';
    tab.id = `emp-tab-${emp.id}`;
    tab.innerHTML = `
      <div class="emp-avatar">${emp.name.charAt(0)}</div>
      <span>${emp.name}</span>
      <span class="emp-badge-amount">${emp.amount}</span>
    `;
    tab.addEventListener('click', () => {
      // User clicked on left tab: switch document and set name, keeping remaining fields blank
      selectEmployee(emp.id, false);
      prepareEmployeeForm(emp);
    });
    employeeTabs.appendChild(tab);
  });
}

function selectEmployeeByIndex(idx, autoFill = false) {
  const list = EXPENSE_DATA[currentLang];
  if (list && list[idx]) {
    selectEmployee(list[idx].id, autoFill);
  }
}

// Current Document View Mode: 'image' (raw photo/scan) or 'text' (structured OCR text)
let currentDocMode = 'image';

// Render Document View (either Raw Image or Structured OCR Text)
function renderDocView(emp, mode = currentDocMode) {
  if (!emp) return;
  currentDocMode = mode;
  const t = I18N[currentLang];

  if (mode === 'image') {
    docViewer.innerHTML = `
      <div class="doc-top-bar">
        <span class="doc-tag">${t.imageTag}</span>
        <div class="doc-action-group">
          <button class="doc-ocr-btn" id="btnOcrAction">
            <svg width="13" height="13" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <path d="M14 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V8z"></path>
              <polyline points="14 2 14 8 20 8"></polyline>
              <line x1="16" y1="13" x2="8" y2="13"></line>
              <line x1="16" y1="17" x2="8" y2="17"></line>
            </svg>
            ${t.ocrBtn}
          </button>
        </div>
      </div>
      <div class="receipt-image-wrapper" id="receiptImgWrapper">
        <div class="scan-shimmer-layer"></div>
        <img src="${emp.imageSrc}" alt="${emp.name} 票据原件" class="receipt-image" id="receiptImgEl" title="${t.ocrBtn}" />
      </div>
    `;

    const btnOcr = document.getElementById('btnOcrAction');
    if (btnOcr) btnOcr.addEventListener('click', convertDocToText);
    const imgEl = document.getElementById('receiptImgEl');
    if (imgEl) imgEl.addEventListener('click', convertDocToText);
  } else {
    docViewer.innerHTML = `
      <div class="doc-top-bar">
        <span class="doc-tag">${t.textTag}</span>
        <div class="doc-action-group">
          <button class="doc-mode-toggle-btn" id="btnViewImgAction">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect>
              <circle cx="8.5" cy="8.5" r="1.5"></circle>
              <polyline points="21 15 16 10 5 21"></polyline>
            </svg>
            ${t.viewImageBtn}
          </button>
          <button class="doc-copy-btn" id="btnCopyDocAction">
            <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
              <rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>
              <path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>
            </svg>
            ${t.copyDocBtn}
          </button>
        </div>
      </div>
      <div class="fade-in-doc">
        ${emp.htmlContent}
      </div>
    `;

    const btnViewImg = document.getElementById('btnViewImgAction');
    if (btnViewImg) btnViewImg.addEventListener('click', viewOriginalImage);
    const btnCopyDoc = document.getElementById('btnCopyDocAction');
    if (btnCopyDoc) btnCopyDoc.addEventListener('click', copyCurrentDocText);

    bindEvidenceClicks();
  }
}

// Convert Document to Structured Text (OCR)
function convertDocToText() {
  const wrapper = document.getElementById('receiptImgWrapper');
  if (wrapper) {
    wrapper.classList.add('scanning-active');
  }
  setTimeout(() => {
    currentDocMode = 'text';
    if (currentViewEmployee) {
      renderDocView(currentViewEmployee, 'text');
    }
  }, 350);
}

// View Original Image
function viewOriginalImage() {
  currentDocMode = 'image';
  if (currentViewEmployee) {
    renderDocView(currentViewEmployee, 'image');
  }
}

// Select Employee and load document into Left Pane
function selectEmployee(empId, autoFill = false) {
  const list = EXPENSE_DATA[currentLang];
  const emp = list.find(e => e.id === empId);
  if (!emp) return;

  currentViewEmployee = emp;

  // Update active tab style
  document.querySelectorAll('.emp-tab-chip').forEach(c => c.classList.remove('active'));
  const activeTab = document.getElementById(`emp-tab-${emp.id}`);
  if (activeTab) activeTab.classList.add('active');

  // Load document (default to raw image mode)
  renderDocView(emp, 'image');

  // Only auto-fill if explicitly requested
  if (autoFill) {
    fillFormWithEmployee(emp);
  }
}

// Prepare form: CLEAR ALL fields including claimant name (DO NOT AUTO-FILL NAME)
function prepareEmployeeForm(emp) {
  currentFilledEmployee = null;
  clearInterval(currentTypingTimer);

  // Clear all fields including claimant name as requested by user
  if (formInputs.claimant) formInputs.claimant.value = '';
  if (formInputs.empId) formInputs.empId.value = '';
  if (formInputs.dept) formInputs.dept.value = '';
  if (formInputs.category) formInputs.category.value = '';
  if (formInputs.amount) formInputs.amount.value = '';
  if (formInputs.date) formInputs.date.value = '';
  if (formInputs.invoiceNo) formInputs.invoiceNo.value = '';
  if (formInputs.purpose) formInputs.purpose.value = '';

  renderIdleVerdict();

  if (docViewer) {
    docViewer.querySelectorAll('.evidence-mark').forEach(m => {
      m.classList.remove('highlight-matched', 'locate-pulse');
    });
  }
}

// Fill Right Pane Form fields & Audit Engine (called on "Fill by Name" or "Fill Current Doc")
function fillFormWithEmployee(emp, useAnimation = true) {
  if (!emp) return;
  currentFilledEmployee = emp;

  formInputs.claimant.value = emp.name;
  formInputs.empId.value = emp.empId;
  formInputs.dept.value = emp.dept;
  formInputs.category.value = emp.category;
  formInputs.amount.value = emp.amount;
  formInputs.date.value = emp.date;
  formInputs.invoiceNo.value = emp.invoiceNo;
  formInputs.purpose.value = emp.purpose;

  // If currently in image mode, automatically switch to structured text so evidence can be inspected
  if (currentDocMode !== 'text') {
    renderDocView(emp, 'text');
  }

  // Render Compact Audit Verdict & Highlights
  renderAuditVerdict(emp.verdict);
  highlightAllMatchedEvidence();
}

// Clear all form inputs and reset verdict to idle state
function clearForm(showToastMsg = true) {
  currentFilledEmployee = null;
  clearInterval(currentTypingTimer);

  Object.values(formInputs).forEach(input => {
    if (input) input.value = '';
  });

  renderIdleVerdict();

  // Clear highlights in docViewer
  if (docViewer) {
    docViewer.querySelectorAll('.evidence-mark').forEach(m => {
      m.classList.remove('highlight-matched', 'locate-pulse');
    });
  }

  if (showToastMsg) {
    showToast(I18N[currentLang].clearedToast);
  }
}

// Render Compact Audit Verdict Card (Significantly shortened vertically)
function renderAuditVerdict(verdict) {
  if (!verdict) {
    renderIdleVerdict();
    return;
  }

  const t = I18N[currentLang];
  let stampClass = 'pass';
  let stampText = t.statusPass;
  let icon = '●';

  if (verdict.status === 'reject') {
    stampClass = 'reject';
    stampText = t.statusReject;
    icon = '✕';
  } else if (verdict.status === 'warn') {
    stampClass = 'warn';
    stampText = t.statusWarn;
    icon = '▲';
  }

  verdictCard.innerHTML = `
    <div class="verdict-header-compact">
      <div class="verdict-stamp ${stampClass}">
        <span>${icon}</span>
        <span>${stampText}</span>
      </div>
      <div class="verdict-rule-chips">
        ${verdict.rules.map(rule => `
          <span class="rule-chip ${rule.status}">
            <span>${rule.status === 'pass' ? '✓' : (rule.status === 'fail' ? '✕' : '▲')}</span>
            <span>${rule.title}</span>
          </span>
        `).join('')}
      </div>
    </div>
    <div class="verdict-summary-compact">
      <strong>${verdict.headline}</strong> — ${verdict.summary}
    </div>
  `;
}

// Render Idle / Awaiting Input State for Verdict Card
function renderIdleVerdict() {
  const t = I18N[currentLang];
  verdictCard.innerHTML = `
    <div class="verdict-header-compact">
      <div class="verdict-stamp idle">
        <span>○</span>
        <span>${t.statusIdle}</span>
      </div>
      <span style="font-size:11px; color:var(--text-500);">${t.idleHint}</span>
    </div>
  `;
}

// Trigger Fill by Claimant Name (typed in inputClaimant or passed directly)
function triggerFillByName(nameQuery) {
  const list = EXPENSE_DATA[currentLang];
  const query = (nameQuery || formInputs.claimant.value).trim().toLowerCase();

  let found = null;
  if (query) {
    found = list.find(e => 
      e.name.toLowerCase() === query ||
      e.name.toLowerCase().includes(query) ||
      query.includes(e.name.toLowerCase()) ||
      e.empId.toLowerCase().includes(query) ||
      ((query.includes('思奇') || query.includes('思琪') || query.includes('lisiqi')) && e.id === 'lisiqi')
    );
  }

  // Fallback to current viewing employee if input matches or is currently selected
  if (!found && currentViewEmployee) {
    found = currentViewEmployee;
  }

  if (!found) {
    showToast(I18N[currentLang].notFoundToast);
    renderIdleVerdict();
    return;
  }

  // Switch Left Pane to matching employee
  selectEmployee(found.id, false);

  // Fill remaining fields and verify
  fillFormWithEmployee(found, true);
}

// Fill Current Employee from Left Pane
function fillCurrentEmployee() {
  if (!currentViewEmployee) return;
  fillFormWithEmployee(currentViewEmployee, true);
}

// Simple typewriter animation
function animateTypewriter(inputEl, text, onComplete) {
  inputEl.value = '';
  let i = 0;
  clearInterval(currentTypingTimer);
  currentTypingTimer = setInterval(() => {
    if (i < text.length) {
      inputEl.value += text.charAt(i);
      i++;
    } else {
      clearInterval(currentTypingTimer);
      if (onComplete) onComplete();
    }
  }, 20);
}

// Highlight evidence marks in left document
function highlightAllMatchedEvidence() {
  docViewer.querySelectorAll('.evidence-mark').forEach(m => {
    m.classList.add('highlight-matched');
  });
}

// Double-direction Inspection: Locate Evidence in Left Pane
function locateEvidenceInDoc(fieldName) {
  const mark = docViewer.querySelector(`.evidence-mark[data-field="${fieldName}"]`) || 
               docViewer.querySelector(`.evidence-mark#ev-${fieldName}`);

  if (mark) {
    mark.scrollIntoView({ behavior: 'smooth', block: 'center' });
    mark.classList.remove('locate-pulse');
    void mark.offsetWidth; // reflow
    mark.classList.add('locate-pulse');
  }
}

// Bind Evidence Mark Clicks to Focus Form
function bindEvidenceClicks() {
  docViewer.querySelectorAll('.evidence-mark').forEach(el => {
    el.addEventListener('click', () => {
      const field = el.getAttribute('data-field');
      if (field && formInputs[field]) {
        formInputs[field].focus();
        formInputs[field].scrollIntoView({ behavior: 'smooth', block: 'center' });
        showToast(currentLang === 'zh' ? `已聚焦字段: ${field}` : `Focused field: ${field}`);
      }
    });
  });
}

// Copy Document Clean Text (with rich visual animation)
function copyCurrentDocText() {
  const target = currentFilledEmployee || currentViewEmployee;
  if (!target) return;

  const t = I18N[currentLang];
  const text = `
[${t.brandTitle}]
${t.fieldClaimant}: ${target.name} (${target.empId})
${t.fieldDept}: ${target.dept}
${t.fieldAmount}: ${target.amount}
${t.fieldDate}: ${target.date}
${t.fieldCategory}: ${target.category}
${t.fieldInvoice}: ${target.invoiceNo}
${t.fieldPurpose}: ${target.purpose}
  `.trim();

  // 1. Trigger micro-shimmer pulse effect on Left Doc Viewer
  if (docViewer) {
    docViewer.classList.remove('copy-glow-active');
    void docViewer.offsetWidth; // force browser reflow
    docViewer.classList.add('copy-glow-active');
    setTimeout(() => {
      docViewer.classList.remove('copy-glow-active');
    }, 1100);
  }

  // 2. Trigger checkmark state on Copy Button
  const copyBtn = docViewer.querySelector('.doc-copy-btn');
  if (copyBtn) {
    const originalHtml = copyBtn.innerHTML;
    copyBtn.classList.add('copied-success');
    copyBtn.innerHTML = `
      <svg width="12" height="12" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5">
        <polyline points="20 6 9 17 4 12"></polyline>
      </svg>
      ${currentLang === 'zh' ? '已复制单据文本' : 'Copied!'}
    `;
    setTimeout(() => {
      copyBtn.classList.remove('copied-success');
      copyBtn.innerHTML = originalHtml;
    }, 1600);
  }

  // 3. Write to system clipboard and notify
  navigator.clipboard.writeText(text).then(() => {
    showToast(t.copiedDocToast);
  }).catch(() => {
    showToast(t.copiedDocToast);
  });
}

// Auto-advance to Next Employee in list for continuous smooth demo
function advanceToNextEmployee() {
  const list = EXPENSE_DATA[currentLang];
  if (!list || list.length === 0) return;

  const currentEmp = currentFilledEmployee || currentViewEmployee || list[0];
  let currentIdx = list.findIndex(e => e.id === currentEmp.id);
  if (currentIdx === -1) currentIdx = 0;

  const nextIdx = (currentIdx + 1) % list.length;
  const nextEmp = list[nextIdx];

  // Smoothly advance without any blocking toast notifications (satisfying requirement 1)
  setTimeout(() => {
    // Switch left pane document & active tab
    selectEmployee(nextEmp.id, false);
    // Prepare right form with ONLY name, leaving remaining fields blank for demo (satisfying requirement 2)
    prepareEmployeeForm(nextEmp);
  }, 250);
}

// Approve / Reject actions
function handleApprove() {
  advanceToNextEmployee();
}

function handleReject() {
  advanceToNextEmployee();
}

function handleExport() {
  const target = currentFilledEmployee || currentViewEmployee;
  if (!target) return;

  const report = {
    claimant: target.name,
    employeeId: target.empId,
    department: target.dept,
    claimedAmount: target.amount,
    invoiceNo: target.invoiceNo,
    purpose: target.purpose,
    auditVerdict: target.verdict,
    auditedAt: new Date().toISOString()
  };

  const jsonStr = JSON.stringify(report, null, 2);
  navigator.clipboard.writeText(jsonStr).then(() => {
    showToast(I18N[currentLang].exportedToast);
  }).catch(() => {
    showToast(I18N[currentLang].exportedToast);
  });
}

// Event Bindings
function bindEvents() {
  // Claimant name input: Enter to fill by name
  if (formInputs.claimant) {
    formInputs.claimant.addEventListener('keydown', (e) => {
      if (e.key === 'Enter') {
        e.preventDefault();
        triggerFillByName();
      }
    });

    // Auto-match when typing finished or pasted
    formInputs.claimant.addEventListener('input', (e) => {
      const val = e.target.value.trim();
      const list = EXPENSE_DATA[currentLang];
      const match = list.find(emp => 
        emp.name.toLowerCase() === val.toLowerCase() ||
        ((val.includes('思奇') || val.includes('思琪') || val.toLowerCase() === 'lisiqi') && emp.id === 'lisiqi')
      );
      if (match) {
        triggerFillByName(val);
      }
    });
  }

  // Button Fill by Name
  const btnFillByName = document.getElementById('btnFillByName');
  if (btnFillByName) {
    btnFillByName.addEventListener('click', (e) => {
      e.preventDefault();
      triggerFillByName();
    });
  }

  // Button Fill Current Selected Document
  const btnFillSample = document.getElementById('btnFillSample');
  if (btnFillSample) {
    btnFillSample.addEventListener('click', (e) => {
      e.preventDefault();
      fillCurrentEmployee();
    });
  }

  // Button Clear Form
  const btnClearForm = document.getElementById('btnClearForm');
  if (btnClearForm) {
    btnClearForm.addEventListener('click', (e) => {
      e.preventDefault();
      clearForm(true);
    });
  }

  // Locate buttons in form
  document.querySelectorAll('.locate-field-btn[data-target]').forEach(btn => {
    btn.addEventListener('click', (e) => {
      e.preventDefault();
      const field = btn.getAttribute('data-target');
      locateEvidenceInDoc(field);
    });
  });

  // Action buttons
  const btnApprove = document.getElementById('btnApprove');
  const btnReject = document.getElementById('btnReject');
  const btnExport = document.getElementById('btnExport');

  if (btnApprove) btnApprove.addEventListener('click', handleApprove);
  if (btnReject) btnReject.addEventListener('click', handleReject);
  if (btnExport) btnExport.addEventListener('click', handleExport);

  // Language buttons
  document.querySelectorAll('.lang-btn').forEach(btn => {
    btn.addEventListener('click', () => {
      const targetLang = btn.getAttribute('data-lang');
      setLanguage(targetLang);
    });
  });
}

// Toast notification helper
function showToast(message, duration = 2400) {
  const toast = document.createElement('div');
  toast.className = 'geist-toast';
  toast.innerHTML = `
    <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
      <polyline points="20 6 9 17 4 12"></polyline>
    </svg>
    <span>${message}</span>
  `;
  toastContainer.appendChild(toast);

  requestAnimationFrame(() => {
    toast.classList.add('visible');
  });

  setTimeout(() => {
    toast.classList.remove('visible');
    setTimeout(() => toast.remove(), 250);
  }, duration);
}

// Window globally exposed functions
window.copyCurrentDocText = copyCurrentDocText;
window.setLanguage = setLanguage;
window.clearForm = clearForm;
window.triggerFillByName = triggerFillByName;
window.prepareEmployeeForm = prepareEmployeeForm;
window.convertDocToText = convertDocToText;
window.viewOriginalImage = viewOriginalImage;

document.addEventListener('DOMContentLoaded', init);

