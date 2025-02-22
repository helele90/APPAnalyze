//
//  IssueReporter.swift
//  APPAnalyzeCore
//
//  Created by hexiao on 2023/7/20.
//

import Foundation

enum IssueReporter: Reporter {
    static func generateReport() async {
        //
        var map: [String: [Issue]] = [:]
        let allIssues = APPAnalyze.shared.ruleManager.issues
        for issue in allIssues {
            if var issues = map[issue.module] {
                issues.append(Issue(issue: issue))
                map[issue.module] = issues
            } else {
                map[issue.module] = [Issue(issue: issue)]
            }
        }
        //
        APPAnalyze.shared.reporterManager.generateReport(data: map.data, fileName: "issues.json")
        //
        let encoder = JSONEncoder()
        let data = try! encoder.encode(map)
        let string = String(data: data, encoding: .utf8)!
        let script = "<script>var issuesData = \(string);</script>"
        //
        let appIssueHTML = """
        <!doctype html><html><head><meta charset="utf-8"/><meta name="viewport"content="width=device-width, initial-scale=1.0"/><style type="text/css">body{font-family:Arial,Helvetica,sans-serif;font-size:0.9rem}a{text-decoration:none}table{border:1px solid gray;border-collapse:collapse;-moz-box-shadow:3px 3px 4px#AAA;-webkit-box-shadow:3px 3px 4px#AAA;box-shadow:3px 3px 4px#AAA;vertical-align:top;height:64px}td,th{border:1px solid#D3D3D3;padding:5px 10px 5px 10px;text-align:center}th{border-bottom:1px solid black;background-color:#FAFAFA}</style><title>问题数量</title>\(script)<script>function onLoad(){const data=issuesData;let items=new Array();for(let name in data){const issues=data[name];let count=0;let safeCount=0;let performanceCount=0;let packageSizeCount=0;let antiPatternCount=0;for(let i=0;i<issues.length;i++){const issue=issues[i];const info=issue.info;let issueLength=1;if(Array.isArray(info)){issueLength=info.length}if(issueLength==0){issueLength=1}count+=issueLength;const type=issue.type;if(type=='安全'){safeCount+=issueLength}else if(type=='启动性能'||type=='性能'){performanceCount+=issueLength}else if(type=='包体积'){packageSizeCount+=issueLength}else if(type=='组件依赖规范'){antiPatternCount+=issueLength}}items.push({name,safeCount,performanceCount,packageSizeCount,antiPatternCount,count})}let sortedItems=items.sort(function(a,b){return b.count-a.count});let trs='';for(let i=0;i<sortedItems.length;i++){const item=sortedItems[i];const link=`./module_issues.html?module=${item.name}`;const tr=`<tr><td>${i+1}</td><td><a target="_blank"href="${link}">${item.name}</a></td><td>${item.packageSizeCount}</td><td>${item.performanceCount}</td><td>${item.antiPatternCount}</td><td>${item.safeCount}</td><td>${item.count}</td></tr>`;trs+=tr}document.getElementById('module_tbody').innerHTML=trs}</script></head><body onload="onLoad()"><h2>问题数量</h2><table><thead><tr><th style="width: 50pt;"><b>序号</b></th><th style="width: 120pt;"><b>模块名</b></th><th style="width: 60pt;"><b>包体积</b></th><th style="width: 60pt;"><b>性能</b></th><th style="width: 60pt;"><b>组件依赖</b></th><th style="width: 60pt;"><b>安全</b></th><th style="width: 60pt;"><b>总数</b></th></tr></thead><tbody id="module_tbody"></tbody></table><br/></body></html>
        """
        //
        APPAnalyze.shared.reporterManager.generateReport(text: appIssueHTML, fileName: "app_issues.html")
        //
        let frameworkIssueHTML = """
        <!doctype html><html><head><meta charset="utf-8"/><meta name="viewport"content="width=device-width, initial-scale=1.0"/><style type="text/css">body{font-family:Arial,Helvetica,sans-serif;font-size:0.9rem}table{border:1px solid gray;border-collapse:collapse;-moz-box-shadow:3px 3px 4px#AAA;-webkit-box-shadow:3px 3px 4px#AAA;box-shadow:3px 3px 4px#AAA;vertical-align:top;height:64px}td,th{border:1px solid#D3D3D3;padding:5px 10px 5px 10px;text-align:center}th{border-bottom:1px solid black;background-color:#FAFAFA}#orange{background-color:orange;color:white}#red{background-color:red;color:white}</style><title>模块问题</title>\(script)<script>function getPackageSizeInfo(module){const issues=issuesData[module];let trs='';let index=1;for(let i=0;i<issues.length;i++){const issue=issues[i];const info=issue.info;if(Array.isArray(info)&&info.length>0){for(let i=0;i<info.length;i++){const style=issue.severity=='Warning'?'orange':'red';const tr=`<tr><td>${index}</td><td>${issue.name}</td><td>${JSON.stringify(info[i],null,2)}</td><td id="${style}">${issue.severity}</td><td>${issue.type}</td><td>${issue.message}</td></tr>`;trs+=tr;index+=1}}else{const style=issue.severity=='Warning'?'orange':'red';const tr=`<tr><td>${index}</td><td>${issue.name}</td><td>${JSON.stringify(issue.info,null,2)}</td><td id="${style}">${issue.severity}</td><td>${issue.type}</td><td>${issue.message}</td></tr>`;trs+=tr;index+=1}}document.getElementById('module_tbody').innerHTML=trs}function onLoad(){const module=getQueryVariable('module');getPackageSizeInfo(module);document.getElementById('module').innerHTML=`${module}`}function getQueryVariable(variable){var query=window.location.search.substring(1);var vars=query.split("&");for(var i=0;i<vars.length;i++){var pair=vars[i].split("=");if(pair[0]==variable){return pair[1]}}return(false)}</script></head><body onload="onLoad()"><h2>模块</h2><h3 id='module'></h3><h2>问题列表</h2><table><thead><tr><th style="width: 50pt;"><b>序号</b></th><th style="width: 120pt;"><b>问题</b></th><th style="width: 60pt;"><b>数据</b></th><th style="width: 60pt;"><b>严重性</b></th><th style="width: 60pt;"><b>类型</b></th><th style="width: 160pt;"><b>消息</b></th></tr></thead><tbody id="module_tbody"></tbody></table></body></html>
        """
        APPAnalyze.shared.reporterManager.generateReport(text: frameworkIssueHTML, fileName: "module_issues.html")
    }
}
