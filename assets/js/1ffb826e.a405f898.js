(window.webpackJsonp=window.webpackJsonp||[]).push([[14],{132:function(e,t,r){"use strict";r.d(t,"a",(function(){return d})),r.d(t,"b",(function(){return u}));var a=r(0),n=r.n(a);function l(e,t,r){return t in e?Object.defineProperty(e,t,{value:r,enumerable:!0,configurable:!0,writable:!0}):e[t]=r,e}function o(e,t){var r=Object.keys(e);if(Object.getOwnPropertySymbols){var a=Object.getOwnPropertySymbols(e);t&&(a=a.filter((function(t){return Object.getOwnPropertyDescriptor(e,t).enumerable}))),r.push.apply(r,a)}return r}function b(e){for(var t=1;t<arguments.length;t++){var r=null!=arguments[t]?arguments[t]:{};t%2?o(Object(r),!0).forEach((function(t){l(e,t,r[t])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(r)):o(Object(r)).forEach((function(t){Object.defineProperty(e,t,Object.getOwnPropertyDescriptor(r,t))}))}return e}function c(e,t){if(null==e)return{};var r,a,n=function(e,t){if(null==e)return{};var r,a,n={},l=Object.keys(e);for(a=0;a<l.length;a++)r=l[a],t.indexOf(r)>=0||(n[r]=e[r]);return n}(e,t);if(Object.getOwnPropertySymbols){var l=Object.getOwnPropertySymbols(e);for(a=0;a<l.length;a++)r=l[a],t.indexOf(r)>=0||Object.prototype.propertyIsEnumerable.call(e,r)&&(n[r]=e[r])}return n}var i=n.a.createContext({}),p=function(e){var t=n.a.useContext(i),r=t;return e&&(r="function"==typeof e?e(t):b(b({},t),e)),r},d=function(e){var t=p(e.components);return n.a.createElement(i.Provider,{value:t},e.children)},m={inlineCode:"code",wrapper:function(e){var t=e.children;return n.a.createElement(n.a.Fragment,{},t)}},s=n.a.forwardRef((function(e,t){var r=e.components,a=e.mdxType,l=e.originalType,o=e.parentName,i=c(e,["components","mdxType","originalType","parentName"]),d=p(r),s=a,u=d["".concat(o,".").concat(s)]||d[s]||m[s]||l;return r?n.a.createElement(u,b(b({ref:t},i),{},{components:r})):n.a.createElement(u,b({ref:t},i))}));function u(e,t){var r=arguments,a=t&&t.mdxType;if("string"==typeof e||a){var l=r.length,o=new Array(l);o[0]=s;var b={};for(var c in t)hasOwnProperty.call(t,c)&&(b[c]=t[c]);b.originalType=e,b.mdxType="string"==typeof e?e:a,o[1]=b;for(var i=2;i<l;i++)o[i]=r[i];return n.a.createElement.apply(null,o)}return n.a.createElement.apply(null,r)}s.displayName="MDXCreateElement"},84:function(e,t,r){"use strict";r.r(t),r.d(t,"frontMatter",(function(){return o})),r.d(t,"metadata",(function(){return b})),r.d(t,"toc",(function(){return c})),r.d(t,"default",(function(){return p}));var a=r(3),n=r(7),l=(r(0),r(132)),o={},b={unversionedId:"Core/classes/CloudKitSynchronizerSharing",id:"Core/classes/CloudKitSynchronizerSharing",isDocsHomePage:!1,title:"CloudKitSynchronizerSharing",description:"EXTENSION",source:"@site/docs/Core/classes/CloudKitSynchronizerSharing.md",slug:"/Core/classes/CloudKitSynchronizerSharing",permalink:"/SyncKit/Core/classes/CloudKitSynchronizerSharing",editUrl:"https://github.com/facebook/docusaurus/edit/master/website/docs/Core/classes/CloudKitSynchronizerSharing.md",version:"current",sidebar:"api",previous:{title:"CloudKitSynchronizer",permalink:"/SyncKit/Core/classes/CloudKitSynchronizer"},next:{title:"CloudKitSynchronizerSubscription",permalink:"/SyncKit/Core/classes/CloudKitSynchronizerSubscription"}},c=[{value:"<code>share(for:)</code>",id:"sharefor",children:[]},{value:"<code>cloudSharingControllerDidSaveShare(_:for:)</code>",id:"cloudsharingcontrollerdidsaveshare_for",children:[]},{value:"<code>cloudSharingControllerDidStopSharing(for:)</code>",id:"cloudsharingcontrollerdidstopsharingfor",children:[]},{value:"<code>share(object:publicPermission:participants:completion:)</code>",id:"shareobjectpublicpermissionparticipantscompletion",children:[]},{value:"<code>removeShare(for:completion:)</code>",id:"removeshareforcompletion",children:[]},{value:"<code>reuploadRecordsForChildrenOf(root:completion:)</code>",id:"reuploadrecordsforchildrenofrootcompletion",children:[]}],i={toc:c};function p(e){var t=e.components,r=Object(n.a)(e,["components"]);return Object(l.b)("wrapper",Object(a.a)({},i,r,{components:t,mdxType:"MDXLayout"}),Object(l.b)("p",null,Object(l.b)("strong",{parentName:"p"},"EXTENSION")),Object(l.b)("h1",{id:"cloudkitsynchronizer"},Object(l.b)("inlineCode",{parentName:"h1"},"CloudKitSynchronizer")),Object(l.b)("pre",null,Object(l.b)("code",{parentName:"pre",className:"language-swift"},"extension CloudKitSynchronizer\n")),Object(l.b)("h3",{id:"sharefor"},Object(l.b)("inlineCode",{parentName:"h3"},"share(for:)")),Object(l.b)("pre",null,Object(l.b)("code",{parentName:"pre",className:"language-swift"},"@objc func share(for object: AnyObject) -> CKShare?\n")),Object(l.b)("p",null,"Returns the locally stored ",Object(l.b)("inlineCode",{parentName:"p"},"CKShare")," for a given model object."),Object(l.b)("ul",null,Object(l.b)("li",{parentName:"ul"},"Parameter object  The model object."),Object(l.b)("li",{parentName:"ul"},"Returns: ",Object(l.b)("inlineCode",{parentName:"li"},"CKShare")," stored for the given object.")),Object(l.b)("h4",{id:"parameters"},"Parameters"),Object(l.b)("table",null,Object(l.b)("thead",{parentName:"table"},Object(l.b)("tr",{parentName:"thead"},Object(l.b)("th",{parentName:"tr",align:null},"Name"),Object(l.b)("th",{parentName:"tr",align:null},"Description"))),Object(l.b)("tbody",{parentName:"table"},Object(l.b)("tr",{parentName:"tbody"},Object(l.b)("td",{parentName:"tr",align:null},"object  The model object."),Object(l.b)("td",{parentName:"tr",align:null})))),Object(l.b)("h3",{id:"cloudsharingcontrollerdidsaveshare_for"},Object(l.b)("inlineCode",{parentName:"h3"},"cloudSharingControllerDidSaveShare(_:for:)")),Object(l.b)("pre",null,Object(l.b)("code",{parentName:"pre",className:"language-swift"},"@objc func cloudSharingControllerDidSaveShare(_ share: CKShare, for object: AnyObject)\n")),Object(l.b)("p",null,"Saves the given ",Object(l.b)("inlineCode",{parentName:"p"},"CKShare")," locally for the given model object."),Object(l.b)("ul",null,Object(l.b)("li",{parentName:"ul"},Object(l.b)("p",{parentName:"li"},"Parameters:"),Object(l.b)("ul",{parentName:"li"},Object(l.b)("li",{parentName:"ul"},Object(l.b)("p",{parentName:"li"},"share The ",Object(l.b)("inlineCode",{parentName:"p"},"CKShare"),".")),Object(l.b)("li",{parentName:"ul"},Object(l.b)("p",{parentName:"li"},"object  The model object."),Object(l.b)("p",{parentName:"li"},"This method should be called by your ",Object(l.b)("inlineCode",{parentName:"p"},"UICloudSharingControllerDelegate"),", when ",Object(l.b)("inlineCode",{parentName:"p"},"cloudSharingControllerDidSaveShare")," is called."))))),Object(l.b)("h4",{id:"parameters-1"},"Parameters"),Object(l.b)("table",null,Object(l.b)("thead",{parentName:"table"},Object(l.b)("tr",{parentName:"thead"},Object(l.b)("th",{parentName:"tr",align:null},"Name"),Object(l.b)("th",{parentName:"tr",align:null},"Description"))),Object(l.b)("tbody",{parentName:"table"},Object(l.b)("tr",{parentName:"tbody"},Object(l.b)("td",{parentName:"tr",align:null},"share The"),Object(l.b)("td",{parentName:"tr",align:null},Object(l.b)("inlineCode",{parentName:"td"},"CKShare"),".")),Object(l.b)("tr",{parentName:"tbody"},Object(l.b)("td",{parentName:"tr",align:null},"object  The model object."),Object(l.b)("td",{parentName:"tr",align:null})))),Object(l.b)("h3",{id:"cloudsharingcontrollerdidstopsharingfor"},Object(l.b)("inlineCode",{parentName:"h3"},"cloudSharingControllerDidStopSharing(for:)")),Object(l.b)("pre",null,Object(l.b)("code",{parentName:"pre",className:"language-swift"},"@objc func cloudSharingControllerDidStopSharing(for object: AnyObject)\n")),Object(l.b)("p",null,"Deletes any ",Object(l.b)("inlineCode",{parentName:"p"},"CKShare")," locally stored  for the given model object."),Object(l.b)("ul",null,Object(l.b)("li",{parentName:"ul"},"Parameters:",Object(l.b)("ul",{parentName:"li"},Object(l.b)("li",{parentName:"ul"},"object  The model object.\nThis method should be called by your ",Object(l.b)("inlineCode",{parentName:"li"},"UICloudSharingControllerDelegate"),", when ",Object(l.b)("inlineCode",{parentName:"li"},"cloudSharingControllerDidStopSharing")," is called.")))),Object(l.b)("h4",{id:"parameters-2"},"Parameters"),Object(l.b)("table",null,Object(l.b)("thead",{parentName:"table"},Object(l.b)("tr",{parentName:"thead"},Object(l.b)("th",{parentName:"tr",align:null},"Name"),Object(l.b)("th",{parentName:"tr",align:null},"Description"))),Object(l.b)("tbody",{parentName:"table"},Object(l.b)("tr",{parentName:"tbody"},Object(l.b)("td",{parentName:"tr",align:null},"object  The model object."),Object(l.b)("td",{parentName:"tr",align:null},"This method should be called by your ",Object(l.b)("inlineCode",{parentName:"td"},"UICloudSharingControllerDelegate"),", when ",Object(l.b)("inlineCode",{parentName:"td"},"cloudSharingControllerDidStopSharing")," is called.")))),Object(l.b)("h3",{id:"shareobjectpublicpermissionparticipantscompletion"},Object(l.b)("inlineCode",{parentName:"h3"},"share(object:publicPermission:participants:completion:)")),Object(l.b)("pre",null,Object(l.b)("code",{parentName:"pre",className:"language-swift"},"@objc func share(object: AnyObject, publicPermission: CKShare.Participant.Permission, participants: [CKShare.Participant], completion: ((CKShare?, Error?) -> ())?)\n")),Object(l.b)("p",null,"Returns a  ",Object(l.b)("inlineCode",{parentName:"p"},"CKShare")," for the given model object. If one does not exist, it creates and uploads a new"),Object(l.b)("ul",null,Object(l.b)("li",{parentName:"ul"},"Parameters:",Object(l.b)("ul",{parentName:"li"},Object(l.b)("li",{parentName:"ul"},"object The model object to share."),Object(l.b)("li",{parentName:"ul"},"publicPermission  The permissions to be used for the new share."),Object(l.b)("li",{parentName:"ul"},"participants: The participants to add to this share."),Object(l.b)("li",{parentName:"ul"},"completion: Closure that gets called with an optional error when the operation is completed.")))),Object(l.b)("h4",{id:"parameters-3"},"Parameters"),Object(l.b)("table",null,Object(l.b)("thead",{parentName:"table"},Object(l.b)("tr",{parentName:"thead"},Object(l.b)("th",{parentName:"tr",align:null},"Name"),Object(l.b)("th",{parentName:"tr",align:null},"Description"))),Object(l.b)("tbody",{parentName:"table"},Object(l.b)("tr",{parentName:"tbody"},Object(l.b)("td",{parentName:"tr",align:null},"object The model object to share."),Object(l.b)("td",{parentName:"tr",align:null})),Object(l.b)("tr",{parentName:"tbody"},Object(l.b)("td",{parentName:"tr",align:null},"publicPermission  The permissions to be used for the new share."),Object(l.b)("td",{parentName:"tr",align:null})),Object(l.b)("tr",{parentName:"tbody"},Object(l.b)("td",{parentName:"tr",align:null},"participants"),Object(l.b)("td",{parentName:"tr",align:null},"The participants to add to this share.")),Object(l.b)("tr",{parentName:"tbody"},Object(l.b)("td",{parentName:"tr",align:null},"completion"),Object(l.b)("td",{parentName:"tr",align:null},"Closure that gets called with an optional error when the operation is completed.")))),Object(l.b)("h3",{id:"removeshareforcompletion"},Object(l.b)("inlineCode",{parentName:"h3"},"removeShare(for:completion:)")),Object(l.b)("pre",null,Object(l.b)("code",{parentName:"pre",className:"language-swift"},"@objc func removeShare(for object: AnyObject, completion: ((Error?) -> ())?)\n")),Object(l.b)("p",null,"Removes the existing ",Object(l.b)("inlineCode",{parentName:"p"},"CKShare")," for an object and deletes it from CloudKit."),Object(l.b)("ul",null,Object(l.b)("li",{parentName:"ul"},"Parameters:",Object(l.b)("ul",{parentName:"li"},Object(l.b)("li",{parentName:"ul"},"object  The model object."),Object(l.b)("li",{parentName:"ul"},"completion Closure that gets called on completion.")))),Object(l.b)("h4",{id:"parameters-4"},"Parameters"),Object(l.b)("table",null,Object(l.b)("thead",{parentName:"table"},Object(l.b)("tr",{parentName:"thead"},Object(l.b)("th",{parentName:"tr",align:null},"Name"),Object(l.b)("th",{parentName:"tr",align:null},"Description"))),Object(l.b)("tbody",{parentName:"table"},Object(l.b)("tr",{parentName:"tbody"},Object(l.b)("td",{parentName:"tr",align:null},"object  The model object."),Object(l.b)("td",{parentName:"tr",align:null})),Object(l.b)("tr",{parentName:"tbody"},Object(l.b)("td",{parentName:"tr",align:null},"completion Closure that gets called on completion."),Object(l.b)("td",{parentName:"tr",align:null})))),Object(l.b)("h3",{id:"reuploadrecordsforchildrenofrootcompletion"},Object(l.b)("inlineCode",{parentName:"h3"},"reuploadRecordsForChildrenOf(root:completion:)")),Object(l.b)("pre",null,Object(l.b)("code",{parentName:"pre",className:"language-swift"},"@objc func reuploadRecordsForChildrenOf(root: AnyObject, completion: @escaping ((Error?) -> ()))\n")),Object(l.b)("p",null,"Reuploads to CloudKit all ",Object(l.b)("inlineCode",{parentName:"p"},"CKRecord"),"s for the given root model object and all of its children (see ",Object(l.b)("inlineCode",{parentName:"p"},"ParentKey"),"). This function can be used to ensure all objects in the hierarchy have their ",Object(l.b)("inlineCode",{parentName:"p"},"parent")," property correctly set, before sharing, if their records had been created before sharing was supported."),Object(l.b)("ul",null,Object(l.b)("li",{parentName:"ul"},"Parameters:",Object(l.b)("ul",{parentName:"li"},Object(l.b)("li",{parentName:"ul"},"root The root model object."),Object(l.b)("li",{parentName:"ul"},"completion Closure that gets called on completion.")))),Object(l.b)("h4",{id:"parameters-5"},"Parameters"),Object(l.b)("table",null,Object(l.b)("thead",{parentName:"table"},Object(l.b)("tr",{parentName:"thead"},Object(l.b)("th",{parentName:"tr",align:null},"Name"),Object(l.b)("th",{parentName:"tr",align:null},"Description"))),Object(l.b)("tbody",{parentName:"table"},Object(l.b)("tr",{parentName:"tbody"},Object(l.b)("td",{parentName:"tr",align:null},"root The root model object."),Object(l.b)("td",{parentName:"tr",align:null})),Object(l.b)("tr",{parentName:"tbody"},Object(l.b)("td",{parentName:"tr",align:null},"completion Closure that gets called on completion."),Object(l.b)("td",{parentName:"tr",align:null})))))}p.isMDXComponent=!0}}]);