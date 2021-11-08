(self.webpackChunkdocs_synckit=self.webpackChunkdocs_synckit||[]).push([[5517],{3905:function(e,r,t){"use strict";t.d(r,{Zo:function(){return c},kt:function(){return h}});var a=t(7294);function n(e,r,t){return r in e?Object.defineProperty(e,r,{value:t,enumerable:!0,configurable:!0,writable:!0}):e[r]=t,e}function o(e,r){var t=Object.keys(e);if(Object.getOwnPropertySymbols){var a=Object.getOwnPropertySymbols(e);r&&(a=a.filter((function(r){return Object.getOwnPropertyDescriptor(e,r).enumerable}))),t.push.apply(t,a)}return t}function l(e){for(var r=1;r<arguments.length;r++){var t=null!=arguments[r]?arguments[r]:{};r%2?o(Object(t),!0).forEach((function(r){n(e,r,t[r])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(t)):o(Object(t)).forEach((function(r){Object.defineProperty(e,r,Object.getOwnPropertyDescriptor(t,r))}))}return e}function i(e,r){if(null==e)return{};var t,a,n=function(e,r){if(null==e)return{};var t,a,n={},o=Object.keys(e);for(a=0;a<o.length;a++)t=o[a],r.indexOf(t)>=0||(n[t]=e[t]);return n}(e,r);if(Object.getOwnPropertySymbols){var o=Object.getOwnPropertySymbols(e);for(a=0;a<o.length;a++)t=o[a],r.indexOf(t)>=0||Object.prototype.propertyIsEnumerable.call(e,t)&&(n[t]=e[t])}return n}var d=a.createContext({}),s=function(e){var r=a.useContext(d),t=r;return e&&(t="function"==typeof e?e(r):l(l({},r),e)),t},c=function(e){var r=s(e.components);return a.createElement(d.Provider,{value:r},e.children)},p={inlineCode:"code",wrapper:function(e){var r=e.children;return a.createElement(a.Fragment,{},r)}},u=a.forwardRef((function(e,r){var t=e.components,n=e.mdxType,o=e.originalType,d=e.parentName,c=i(e,["components","mdxType","originalType","parentName"]),u=s(t),h=n,m=u["".concat(d,".").concat(h)]||u[h]||p[h]||o;return t?a.createElement(m,l(l({ref:r},c),{},{components:t})):a.createElement(m,l({ref:r},c))}));function h(e,r){var t=arguments,n=r&&r.mdxType;if("string"==typeof e||n){var o=t.length,l=new Array(o);l[0]=u;var i={};for(var d in r)hasOwnProperty.call(r,d)&&(i[d]=r[d]);i.originalType=e,i.mdxType="string"==typeof e?e:n,l[1]=i;for(var s=2;s<o;s++)l[s]=t[s];return a.createElement.apply(null,l)}return a.createElement.apply(null,t)}u.displayName="MDXCreateElement"},6884:function(e,r,t){"use strict";t.r(r),t.d(r,{frontMatter:function(){return i},contentTitle:function(){return d},metadata:function(){return s},toc:function(){return c},default:function(){return u}});var a=t(2122),n=t(9756),o=(t(7294),t(3905)),l=["components"],i={},d="ModelAdapter",s={unversionedId:"api/core/ModelAdapter",id:"api/core/ModelAdapter",isDocsHomePage:!1,title:"ModelAdapter",description:"An object conforming to ModelAdapter will track the local model, provide changes to upload to CloudKit and import downloaded changes.",source:"@site/docs/api/core/ModelAdapter.md",sourceDirName:"api/core",slug:"/api/core/ModelAdapter",permalink:"/SyncKit/api/core/ModelAdapter",version:"current",frontMatter:{},sidebar:"API",previous:{title:"MergePolicy",permalink:"/SyncKit/api/core/MergePolicy"},next:{title:"Extensions on NSNotification",permalink:"/SyncKit/api/core/NSNotification"}},c=[{value:"Inheritance",id:"inheritance",children:[]},{value:"Requirements",id:"requirements",children:[{value:"hasChanges",id:"haschanges",children:[]},{value:"prepareToImport()",id:"preparetoimport",children:[]},{value:"saveChanges(in:\u200b)",id:"savechangesin",children:[]},{value:"deleteRecords(with:\u200b)",id:"deleterecordswith",children:[]},{value:"persistImportedChanges(completion:\u200b)",id:"persistimportedchangescompletion",children:[]},{value:"recordsToUpload(limit:\u200b)",id:"recordstouploadlimit",children:[]},{value:"didUpload(savedRecords:\u200b)",id:"diduploadsavedrecords",children:[]},{value:"recordIDsMarkedForDeletion(limit:\u200b)",id:"recordidsmarkedfordeletionlimit",children:[]},{value:"didDelete(recordIDs:\u200b)",id:"diddeleterecordids",children:[]},{value:"hasRecordID(_:\u200b)",id:"hasrecordid_",children:[]},{value:"didFinishImport(with:\u200b)",id:"didfinishimportwith",children:[]},{value:"recordZoneID",id:"recordzoneid",children:[]},{value:"serverChangeToken",id:"serverchangetoken",children:[]},{value:"saveToken(_:\u200b)",id:"savetoken_",children:[]},{value:"deleteChangeTracking()",id:"deletechangetracking",children:[]},{value:"mergePolicy",id:"mergepolicy",children:[]},{value:"record(for:\u200b)",id:"recordfor",children:[]},{value:"share(for:\u200b)",id:"sharefor",children:[]},{value:"save(share:\u200bfor:\u200b)",id:"savesharefor",children:[]},{value:"deleteShare(for:\u200b)",id:"deletesharefor",children:[]},{value:"shareForRecordZone()",id:"shareforrecordzone",children:[]},{value:"saveShareForRecordZone(share:\u200b)",id:"saveshareforrecordzoneshare",children:[]},{value:"deleteShareForRecordZone()",id:"deleteshareforrecordzone",children:[]},{value:"recordsToUpdateParentRelationshipsForRoot(_:\u200b)",id:"recordstoupdateparentrelationshipsforroot_",children:[]}]}],p={toc:c};function u(e){var r=e.components,t=(0,n.Z)(e,l);return(0,o.kt)("wrapper",(0,a.Z)({},p,t,{components:r,mdxType:"MDXLayout"}),(0,o.kt)("h1",{id:"modeladapter"},"ModelAdapter"),(0,o.kt)("p",null,"An object conforming to ",(0,o.kt)("inlineCode",{parentName:"p"},"ModelAdapter")," will track the local model, provide changes to upload to CloudKit and import downloaded changes."),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"@objc public protocol ModelAdapter: class \n")),(0,o.kt)("h2",{id:"inheritance"},"Inheritance"),(0,o.kt)("p",null,(0,o.kt)("inlineCode",{parentName:"p"},"class")),(0,o.kt)("h2",{id:"requirements"},"Requirements"),(0,o.kt)("h3",{id:"haschanges"},"hasChanges"),(0,o.kt)("p",null,"Whether the model has any changes"),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"var hasChanges: Bool \n")),(0,o.kt)("h3",{id:"preparetoimport"},"prepareToImport()"),(0,o.kt)("p",null,"Tells the model adapter that an import operation will begin"),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"func prepareToImport()\n")),(0,o.kt)("h3",{id:"savechangesin"},"saveChanges(in:\u200b)"),(0,o.kt)("p",null,"Apply changes in the provided record to the local model objects and save the records."),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"func saveChanges(in records: [CKRecord])\n")),(0,o.kt)("h4",{id:"parameters"},"Parameters"),(0,o.kt)("ul",null,(0,o.kt)("li",{parentName:"ul"},"records: Array of ",(0,o.kt)("inlineCode",{parentName:"li"},"CKRecord")," that were obtained from CloudKit.")),(0,o.kt)("h3",{id:"deleterecordswith"},"deleteRecords(with:\u200b)"),(0,o.kt)("p",null,"Delete the local model objects corresponding to the given record IDs."),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"func deleteRecords(with recordIDs: [CKRecord.ID])\n")),(0,o.kt)("h4",{id:"parameters-1"},"Parameters"),(0,o.kt)("ul",null,(0,o.kt)("li",{parentName:"ul"},"recordIDs: Array of identifiers of records that were deleted on CloudKit.")),(0,o.kt)("h3",{id:"persistimportedchangescompletion"},"persistImportedChanges(completion:\u200b)"),(0,o.kt)("p",null,"Tells the model adapter to persist all downloaded changes in the current import operation."),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"func persistImportedChanges(completion: @escaping (Error?)->())\n")),(0,o.kt)("h4",{id:"parameters-2"},"Parameters"),(0,o.kt)("ul",null,(0,o.kt)("li",{parentName:"ul"},"completion: Block to be called after changes have been persisted.")),(0,o.kt)("h3",{id:"recordstouploadlimit"},"recordsToUpload(limit:\u200b)"),(0,o.kt)("p",null,"Provides an array of up to ",(0,o.kt)("inlineCode",{parentName:"p"},"limit")," records with changes that need to be uploaded to CloudKit."),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"func recordsToUpload(limit: Int) -> [CKRecord]\n")),(0,o.kt)("h4",{id:"parameters-3"},"Parameters"),(0,o.kt)("ul",null,(0,o.kt)("li",{parentName:"ul"},"limit: Maximum number of records that should be provided.")),(0,o.kt)("h4",{id:"returns"},"Returns"),(0,o.kt)("p",null,"Array of ",(0,o.kt)("inlineCode",{parentName:"p"},"CKRecord"),"."),(0,o.kt)("h3",{id:"diduploadsavedrecords"},"didUpload(savedRecords:\u200b)"),(0,o.kt)("p",null,"Tells the model adapter that these records were uploaded successfully to CloudKit."),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"func didUpload(savedRecords: [CKRecord])\n")),(0,o.kt)("h4",{id:"parameters-4"},"Parameters"),(0,o.kt)("ul",null,(0,o.kt)("li",{parentName:"ul"},"savedRecords: Records that were saved.")),(0,o.kt)("h3",{id:"recordidsmarkedfordeletionlimit"},"recordIDsMarkedForDeletion(limit:\u200b)"),(0,o.kt)("p",null,"Provides an array of record IDs to be deleted on CloudKit, for model objects that were deleted locally."),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"func recordIDsMarkedForDeletion(limit: Int) -> [CKRecord.ID]\n")),(0,o.kt)("h4",{id:"parameters-5"},"Parameters"),(0,o.kt)("ul",null,(0,o.kt)("li",{parentName:"ul"},"limit: Maximum number of records that should be provided.")),(0,o.kt)("h4",{id:"returns-1"},"Returns"),(0,o.kt)("p",null,"Array of ",(0,o.kt)("inlineCode",{parentName:"p"},"CKRecordID"),"."),(0,o.kt)("h3",{id:"diddeleterecordids"},"didDelete(recordIDs:\u200b)"),(0,o.kt)("p",null,"Tells the model adapter that these record identifiers were deleted successfully from CloudKit."),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"func didDelete(recordIDs: [CKRecord.ID])\n")),(0,o.kt)("h4",{id:"parameters-6"},"Parameters"),(0,o.kt)("ul",null,(0,o.kt)("li",{parentName:"ul"},"recordIDs: Record IDs that were deleted on CloudKit.")),(0,o.kt)("h3",{id:"hasrecordid_"},"hasRecordID(","_",":\u200b)"),(0,o.kt)("p",null,"Asks the model adapter whether it has a local object for the given record identifier."),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"func hasRecordID(_ recordID: CKRecord.ID) -> Bool\n")),(0,o.kt)("h4",{id:"parameters-7"},"Parameters"),(0,o.kt)("ul",null,(0,o.kt)("li",{parentName:"ul"},"recordID: Record identifier.")),(0,o.kt)("h4",{id:"returns-2"},"Returns"),(0,o.kt)("p",null,"Whether there is a corresponding object for this identifier."),(0,o.kt)("h3",{id:"didfinishimportwith"},"didFinishImport(with:\u200b)"),(0,o.kt)("p",null,"Tells the model adapter that the current import operation finished."),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"func didFinishImport(with error: Error?)\n")),(0,o.kt)("h4",{id:"parameters-8"},"Parameters"),(0,o.kt)("ul",null,(0,o.kt)("li",{parentName:"ul"},"error: Optional error, if any error happened.")),(0,o.kt)("h3",{id:"recordzoneid"},"recordZoneID"),(0,o.kt)("p",null,"Record zone ID managed by this adapter"),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"var recordZoneID: CKRecordZone.ID \n")),(0,o.kt)("h3",{id:"serverchangetoken"},"serverChangeToken"),(0,o.kt)("p",null,"Latest ",(0,o.kt)("inlineCode",{parentName:"p"},"CKServerChangeToken")," stored by this adapter, or ",(0,o.kt)("inlineCode",{parentName:"p"},"nil")," if one does not exist."),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"var serverChangeToken: CKServerChangeToken? \n")),(0,o.kt)("h3",{id:"savetoken_"},"saveToken(","_",":\u200b)"),(0,o.kt)("p",null,"Save given token for future use by this adapter."),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"func saveToken(_ token: CKServerChangeToken?)\n")),(0,o.kt)("h4",{id:"parameters-9"},"Parameters"),(0,o.kt)("ul",null,(0,o.kt)("li",{parentName:"ul"},"token: ",(0,o.kt)("inlineCode",{parentName:"li"},"CKServerChangeToken"))),(0,o.kt)("h3",{id:"deletechangetracking"},"deleteChangeTracking()"),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"func deleteChangeTracking()\n")),(0,o.kt)("ul",null,(0,o.kt)("li",{parentName:"ul"},"Deletes all tracking information and detaches from local model."),(0,o.kt)("li",{parentName:"ul"},"This adapter should not be used after calling this method, create a new adapter if you wish to synchronize"),(0,o.kt)("li",{parentName:"ul"},"the same model again.")),(0,o.kt)("h3",{id:"mergepolicy"},"mergePolicy"),(0,o.kt)("p",null,"Merge policy in case of conflicts. Default is ",(0,o.kt)("inlineCode",{parentName:"p"},"server"),"."),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"var mergePolicy: MergePolicy \n")),(0,o.kt)("h3",{id:"recordfor"},"record(for:\u200b)"),(0,o.kt)("p",null,"Returns corresponding ",(0,o.kt)("inlineCode",{parentName:"p"},"CKRecord")," for the given model object."),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"func record(for object: AnyObject) -> CKRecord?\n")),(0,o.kt)("h4",{id:"parameters-10"},"Parameters"),(0,o.kt)("ul",null,(0,o.kt)("li",{parentName:"ul"},"object: Model object.")),(0,o.kt)("h3",{id:"sharefor"},"share(for:\u200b)"),(0,o.kt)("p",null,"Returns CKShare for the given model object, if one exists."),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"@available(iOS 10.0, OSX 10.12, *) func share(for object: AnyObject) -> CKShare?\n")),(0,o.kt)("h4",{id:"parameters-11"},"Parameters"),(0,o.kt)("ul",null,(0,o.kt)("li",{parentName:"ul"},"object: Model object.")),(0,o.kt)("h3",{id:"savesharefor"},"save(share:\u200bfor:\u200b)"),(0,o.kt)("p",null,"Store CKShare for given model object."),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"@available(iOS 10.0, OSX 10.12, *) func save(share: CKShare, for object: AnyObject)\n")),(0,o.kt)("h4",{id:"parameters-12"},"Parameters"),(0,o.kt)("ul",null,(0,o.kt)("li",{parentName:"ul"},"share: ",(0,o.kt)("inlineCode",{parentName:"li"},"CKShare")," object to save."),(0,o.kt)("li",{parentName:"ul"},"object: Model object.")),(0,o.kt)("h3",{id:"deletesharefor"},"deleteShare(for:\u200b)"),(0,o.kt)("p",null,"Delete existing ",(0,o.kt)("inlineCode",{parentName:"p"},"CKShare")," for given model object."),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"@available(iOS 10.0, OSX 10.12, *) func deleteShare(for object: AnyObject)\n")),(0,o.kt)("h4",{id:"parameters-13"},"Parameters"),(0,o.kt)("ul",null,(0,o.kt)("li",{parentName:"ul"},"object: Model object.")),(0,o.kt)("h3",{id:"shareforrecordzone"},"shareForRecordZone()"),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"@available(iOS 15.0, OSX 12, *) func shareForRecordZone() -> CKShare?\n")),(0,o.kt)("ul",null,(0,o.kt)("li",{parentName:"ul"},"Returns: CKShare for the adapter's record zone, if one exists.")),(0,o.kt)("h3",{id:"saveshareforrecordzoneshare"},"saveShareForRecordZone(share:\u200b)"),(0,o.kt)("p",null,"Store CKShare for the record zone."),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"@available(iOS 15.0, OSX 12, *) func saveShareForRecordZone(share: CKShare)\n")),(0,o.kt)("h4",{id:"parameters-14"},"Parameters"),(0,o.kt)("ul",null,(0,o.kt)("li",{parentName:"ul"},"share: ",(0,o.kt)("inlineCode",{parentName:"li"},"CKShare")," object to save.")),(0,o.kt)("h3",{id:"deleteshareforrecordzone"},"deleteShareForRecordZone()"),(0,o.kt)("p",null,"Delete existing ",(0,o.kt)("inlineCode",{parentName:"p"},"CKShare")," for adapter's record zone."),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"@available(iOS 15.0, OSX 12, *) func deleteShareForRecordZone()\n")),(0,o.kt)("h3",{id:"recordstoupdateparentrelationshipsforroot_"},"recordsToUpdateParentRelationshipsForRoot(","_",":\u200b)"),(0,o.kt)("p",null,"Returns a list of records for the given object and any parent records, recursively."),(0,o.kt)("pre",null,(0,o.kt)("code",{parentName:"pre",className:"language-swift"},"func recordsToUpdateParentRelationshipsForRoot(_ object: AnyObject) -> [CKRecord]\n")),(0,o.kt)("h4",{id:"parameters-15"},"Parameters"),(0,o.kt)("ul",null,(0,o.kt)("li",{parentName:"ul"},"object: Model object.")),(0,o.kt)("h4",{id:"returns-3"},"Returns"),(0,o.kt)("p",null,"Array of ",(0,o.kt)("inlineCode",{parentName:"p"},"CKRecord")))}u.isMDXComponent=!0}}]);