(window.webpackJsonp=window.webpackJsonp||[]).push([[29],{132:function(e,t,a){"use strict";a.d(t,"a",(function(){return d})),a.d(t,"b",(function(){return m}));var r=a(0),n=a.n(r);function o(e,t,a){return t in e?Object.defineProperty(e,t,{value:a,enumerable:!0,configurable:!0,writable:!0}):e[t]=a,e}function c(e,t){var a=Object.keys(e);if(Object.getOwnPropertySymbols){var r=Object.getOwnPropertySymbols(e);t&&(r=r.filter((function(t){return Object.getOwnPropertyDescriptor(e,t).enumerable}))),a.push.apply(a,r)}return a}function i(e){for(var t=1;t<arguments.length;t++){var a=null!=arguments[t]?arguments[t]:{};t%2?c(Object(a),!0).forEach((function(t){o(e,t,a[t])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(a)):c(Object(a)).forEach((function(t){Object.defineProperty(e,t,Object.getOwnPropertyDescriptor(a,t))}))}return e}function p(e,t){if(null==e)return{};var a,r,n=function(e,t){if(null==e)return{};var a,r,n={},o=Object.keys(e);for(r=0;r<o.length;r++)a=o[r],t.indexOf(a)>=0||(n[a]=e[a]);return n}(e,t);if(Object.getOwnPropertySymbols){var o=Object.getOwnPropertySymbols(e);for(r=0;r<o.length;r++)a=o[r],t.indexOf(a)>=0||Object.prototype.propertyIsEnumerable.call(e,a)&&(n[a]=e[a])}return n}var l=n.a.createContext({}),b=function(e){var t=n.a.useContext(l),a=t;return e&&(a="function"==typeof e?e(t):i(i({},t),e)),a},d=function(e){var t=b(e.components);return n.a.createElement(l.Provider,{value:t},e.children)},u={inlineCode:"code",wrapper:function(e){var t=e.children;return n.a.createElement(n.a.Fragment,{},t)}},s=n.a.forwardRef((function(e,t){var a=e.components,r=e.mdxType,o=e.originalType,c=e.parentName,l=p(e,["components","mdxType","originalType","parentName"]),d=b(a),s=r,m=d["".concat(c,".").concat(s)]||d[s]||u[s]||o;return a?n.a.createElement(m,i(i({ref:t},l),{},{components:a})):n.a.createElement(m,i({ref:t},l))}));function m(e,t){var a=arguments,r=t&&t.mdxType;if("string"==typeof e||r){var o=a.length,c=new Array(o);c[0]=s;var i={};for(var p in t)hasOwnProperty.call(t,p)&&(i[p]=t[p]);i.originalType=e,i.mdxType="string"==typeof e?e:r,c[1]=i;for(var l=2;l<o;l++)c[l]=a[l];return n.a.createElement.apply(null,c)}return n.a.createElement.apply(null,a)}s.displayName="MDXCreateElement"},99:function(e,t,a){"use strict";a.r(t),a.d(t,"frontMatter",(function(){return c})),a.d(t,"metadata",(function(){return i})),a.d(t,"toc",(function(){return p})),a.d(t,"default",(function(){return b}));var r=a(3),n=a(7),o=(a(0),a(132)),c={},i={unversionedId:"CoreDataAPI/classes/DefaultCoreDataAdapterProvider",id:"CoreDataAPI/classes/DefaultCoreDataAdapterProvider",isDocsHomePage:!1,title:"DefaultCoreDataAdapterProvider",description:"CLASS",source:"@site/docs/CoreDataAPI/classes/DefaultCoreDataAdapterProvider.md",slug:"/CoreDataAPI/classes/DefaultCoreDataAdapterProvider",permalink:"/SyncKit/CoreDataAPI/classes/DefaultCoreDataAdapterProvider",editUrl:"https://github.com/facebook/docusaurus/edit/master/website/docs/CoreDataAPI/classes/DefaultCoreDataAdapterProvider.md",version:"current",sidebar:"api",previous:{title:"CoreDataStack",permalink:"/SyncKit/CoreDataAPI/classes/CoreDataStack"},next:{title:"CoreDataMultiFetchedResultsController",permalink:"/SyncKit/CoreDataAPI/classes/CoreDataMultiFetchedResultsController"}},p=[{value:"Properties",id:"properties",children:[{value:"<code>adapter</code>",id:"adapter",children:[]}]},{value:"Methods",id:"methods",children:[{value:"<code>init(managedObjectContext:zoneID:appGroup:)</code>",id:"initmanagedobjectcontextzoneidappgroup",children:[]}]}],l={toc:p};function b(e){var t=e.components,a=Object(n.a)(e,["components"]);return Object(o.b)("wrapper",Object(r.a)({},l,a,{components:t,mdxType:"MDXLayout"}),Object(o.b)("p",null,Object(o.b)("strong",{parentName:"p"},"CLASS")),Object(o.b)("h1",{id:"defaultcoredataadapterprovider"},Object(o.b)("inlineCode",{parentName:"h1"},"DefaultCoreDataAdapterProvider")),Object(o.b)("pre",null,Object(o.b)("code",{parentName:"pre",className:"language-swift"},"@objc public class DefaultCoreDataAdapterProvider: NSObject, AdapterProvider\n")),Object(o.b)("p",null,"Default implementation of the ",Object(o.b)("inlineCode",{parentName:"p"},"AdapterProvider"),". Creates a ",Object(o.b)("inlineCode",{parentName:"p"},"CoreDataAdapter")," for the the given ",Object(o.b)("inlineCode",{parentName:"p"},"NSManagedObjectContext")," and record zone ID."),Object(o.b)("h2",{id:"properties"},"Properties"),Object(o.b)("h3",{id:"adapter"},Object(o.b)("inlineCode",{parentName:"h3"},"adapter")),Object(o.b)("pre",null,Object(o.b)("code",{parentName:"pre",className:"language-swift"},"public private(set) var adapter: CoreDataAdapter!\n")),Object(o.b)("h2",{id:"methods"},"Methods"),Object(o.b)("h3",{id:"initmanagedobjectcontextzoneidappgroup"},Object(o.b)("inlineCode",{parentName:"h3"},"init(managedObjectContext:zoneID:appGroup:)")),Object(o.b)("pre",null,Object(o.b)("code",{parentName:"pre",className:"language-swift"},"@objc public init(managedObjectContext: NSManagedObjectContext, zoneID: CKRecordZone.ID, appGroup: String? = nil)\n")),Object(o.b)("p",null,"Create a new model adapter provider."),Object(o.b)("ul",null,Object(o.b)("li",{parentName:"ul"},"Parameters:",Object(o.b)("ul",{parentName:"li"},Object(o.b)("li",{parentName:"ul"},"managedObjectContext: ",Object(o.b)("inlineCode",{parentName:"li"},"NSManagedObjectContext")," to be used by the model adapter."),Object(o.b)("li",{parentName:"ul"},"zoneID: ",Object(o.b)("inlineCode",{parentName:"li"},"CKRecordZone.ID")," to be used by the model adapter."),Object(o.b)("li",{parentName:"ul"},"appGroup: Optional app group.")))),Object(o.b)("h4",{id:"parameters"},"Parameters"),Object(o.b)("table",null,Object(o.b)("thead",{parentName:"table"},Object(o.b)("tr",{parentName:"thead"},Object(o.b)("th",{parentName:"tr",align:null},"Name"),Object(o.b)("th",{parentName:"tr",align:null},"Description"))),Object(o.b)("tbody",{parentName:"table"},Object(o.b)("tr",{parentName:"tbody"},Object(o.b)("td",{parentName:"tr",align:null},"managedObjectContext"),Object(o.b)("td",{parentName:"tr",align:null},Object(o.b)("inlineCode",{parentName:"td"},"NSManagedObjectContext")," to be used by the model adapter.")),Object(o.b)("tr",{parentName:"tbody"},Object(o.b)("td",{parentName:"tr",align:null},"zoneID"),Object(o.b)("td",{parentName:"tr",align:null},Object(o.b)("inlineCode",{parentName:"td"},"CKRecordZone.ID")," to be used by the model adapter.")),Object(o.b)("tr",{parentName:"tbody"},Object(o.b)("td",{parentName:"tr",align:null},"appGroup"),Object(o.b)("td",{parentName:"tr",align:null},"Optional app group.")))))}b.isMDXComponent=!0}}]);