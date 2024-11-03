//
//  SettingsView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 10/13/24.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.presentationMode) var presentationMode
    @State var importing: Bool = false
    @State var backup: Bool = false
    @State var error: Bool = false
    @State var errorMsg :  String? = nil
    @State var backupURL: ActivityURLData? = nil
    
    var body: some View {
        NavigationStack{
            VStack{
                List(){
                    Section("Export") {
                        Button {
                            backup = true
                        } label: {
                            Text("Export")
                        }

                        Button("Import") {
                            importing = true
                        }
                        .fileImporter(
                                   isPresented: $importing,
                                   allowedContentTypes: [.plainText]
                               ) { result in
                                   switch result {
                                   case .success(let file):
                                       Round.importData(file: file)
                                   case .failure(let error):
                                       print(error.localizedDescription)
                                   }
                               }
                    }
                    Section("Support"){
                        Link("Open an issue", destination: URL(string: "https://github.com/tassinari/MaynardGolf/issues")!)
                            .font(.body)
                           
                        

                    }
                    
                    Section("About"){
                        VStack(alignment: .leading){
                            Text("Maynard Golf")
                                .font(.headline)
                                .padding([.bottom],5)
                            Text("Version 1.0")
                                .font(.callout)
                                .foregroundStyle(.gray)
                            Text("by Mark Tassinari")
                                .font(.callout)
                                .foregroundStyle(.gray)
                            
                            Text("Maynard golf is a free and open source software project and not associated with Maynard Golf Club.")
                                .font(.callout)
                                .foregroundStyle(.gray)
                                .padding(.top, 10)
                            
                            
                            Text("View on GitHub:")
                                .font(.callout)
                                .foregroundStyle(.gray)
                                .padding(.top)
                            Text("https://github.com/tassinari/MaynardGolf")
                                .font(.callout)

                        }
                       
                    }
                   
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                        
                    } label: {
                        Text("Done")
                    }
                }
            }
            .alert("Error", isPresented: $error, presenting: errorMsg, actions: { msg in
                VStack {
                    Text(msg)
                        .font(.body)
                        .padding()
        
                }
            })
            .sheet(item: $backupURL, content: { urlData in
                ActivityWrapperView(url: urlData.url)
            })
            .confirmationDialog("What type of data?", isPresented: $backup, titleVisibility: .visible) {
                            
                            Button("CSV File") {
                                do{
                                    let url = try ImportExport.zipCSVData()
                                    backupURL = ActivityURLData(url: url)
                                    
                                }
                                catch let e{
                                    errorMsg = e.localizedDescription
                                    error = true
                                }
                            }

                            Button("Full Database") {
                                do{
                                    let url = try ImportExport.zipData()
                                    backupURL = ActivityURLData(url: url)
                                    
                                }
                                catch let e{
                                    errorMsg = e.localizedDescription
                                    error = true
                                }
                               
                            }
                        }
            
        }
       
    }
}

#Preview {
    SettingsView()
}
