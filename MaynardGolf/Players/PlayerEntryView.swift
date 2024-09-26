//
//  PlayerEntryView.swift
//  MaynardGolf
//
//  Created by Mark Tassinari on 9/13/24.
//

import SwiftUI
import SwiftData
import PhotosUI


enum ImageState {
    case empty
    case loading(Progress)
    case success(UIImage)
    case failure(Error)
}

enum TransferError: Error {
    case importFailed
}

extension ColorValues{
    var color : Color{
        switch self{
        case .blue:
            return .blue
        case .red:
            return .red
        case .green:
            return .green
        case .yellow:
            return .yellow
        case .orange:
            return .orange
        }
    }
}
extension Color{
    var colorValue : ColorValues{
        switch self{
        case .blue:
            return .blue
        case .red:
            return .red
        case .green:
            return .green
        case .yellow:
            return .yellow
        case .orange:
            return .orange
        default:
            return .blue
        }
    }
}


extension PlayerEntryView{
    
    enum PlayerEntryError : Error{
        case userExsists
    }
    
    
    
    @Observable class ViewModel{
        var _photoItem: PhotosPickerItem? = nil
        private(set) var imageState: ImageState = .empty
        var selectedItem: PhotosPickerItem? {
            set{
                if let newValue{
                    let _ = loadTransferable(from: newValue)
                   
                }
                _photoItem = newValue
            }
            get{
                return _photoItem
            }
        }
        var crop : Bool = false
        var scale : CGFloat = 1.0
        var offset : CGSize = .zero
        var color : Color = .blue
        var firstName : String = ""
        var lastName : String = ""
        var exsistsError : Bool = false
        
        func nameExsists(first: String,last : String, context : ModelContext) throws -> Bool{
            
            let predicate = #Predicate<Player> { p in
                p.firstName.localizedStandardContains(first) && p.lastName.localizedStandardContains(last)
            }
            return try context.fetch(FetchDescriptor<Player>(predicate: predicate)).count != 0
            
        }
        
        func addUser( context : ModelContext) throws{
            if firstName.isEmpty || lastName.isEmpty { return }
            if  try nameExsists(first: firstName, last: lastName, context: context){
                throw PlayerEntryError.userExsists
            }
            do{
                //write image
                var savableFileName : String? = nil
                switch imageState {
                case .success(let image):
                    if let data = image.pngData() {
                        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
                        let d = paths[0]
                        let folder = d.appending(component: "pics")
                        savableFileName = "pics/" + firstName + lastName + ".png"
                        let filename = d.appendingPathComponent(savableFileName!)
                        //make pic dir if not there
                        if !FileManager.default.fileExists(atPath: folder.path()){
                            try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                        }
                        try? data.write(to: filename)
                    }
                    break
                case .failure, .empty, .loading:
                    break
                }
                
                let player = Player(firstName: firstName, lastName: lastName, color: color.colorValue, photoPath: savableFileName, scale: scale, offset: offset)
                context.insert(player)
                
                try context.save()
            }catch let e{
                print(String(describing: e))
            }
        }
        var shouldDenyEntry : Bool{
            return firstName.isEmpty || lastName.isEmpty
        }
        
        
        //From Apple demo example
        private func loadTransferable(from imageSelection: PhotosPickerItem) -> Progress {
            return imageSelection.loadTransferable(type: ProfileImage.self) { result in
                DispatchQueue.main.async {
                    guard imageSelection == self.selectedItem else {
                        print("Failed to get the selected item.")
                        return
                    }
                    switch result {
                    case .success(let profileImage?):
                        self.crop = true
                        self.imageState = .success(profileImage.image)
                    case .success(nil):
                        self.imageState = .empty
                    case .failure(let error):
                        self.imageState = .failure(error)
                    }
                }
            }
        }
        
    }
}
struct ProfileImage: Transferable {
    let image: UIImage
    
    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(importedContentType: .image) { data in
//        #if canImport(AppKit)
//            guard let nsImage = NSImage(data: data) else {
//                throw TransferError.importFailed
//            }
//            let image = Image(nsImage: nsImage)
//            return ProfileImage(image: image)
//        #elseif canImport(UIKit)
            guard let uiImage = UIImage(data: data) else {
                throw TransferError.importFailed
            }
            let image = uiImage
            return ProfileImage(image: image)
//        #else
//            throw TransferError.importFailed
//        #endif
        }
    }
}

struct PlayerEntryView: View {
    @Environment(\.presentationMode) var presentationMode
    @Environment(\.modelContext) private var context
   // @Query var players: [Player]
    @Bindable var model : ViewModel = ViewModel()
    
    private let colors : [Color] = [.red, .blue, .green, .yellow, .orange]
    var body: some View {
        NavigationStack {
            VStack{
                
                Text("Create Player")
                    .padding()
                HStack{
                    Spacer()
                    VStack{
                        switch model.imageState {
                    
                        case .success(let image):
                            Image(uiImage: image)
                                .scaleEffect(model.scale)
                                .offset(model.offset)
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(model.color, lineWidth: 5)
                                )
                        case .empty, .loading, .failure:
                            Color(.systemGray5)
                                .frame(width: 120, height: 120)
                                .clipShape(Circle())
                                .overlay(
                                    Circle()
                                        .stroke(model.color, lineWidth: 5)
                                )
                        }
                       
                        PhotosPicker(selection: $model.selectedItem, matching: .any(of: [.images, .not(.screenshots)])) {
                            Text("Select Photo")
                                .padding()
                        }
                        
                        
                    }
                    Spacer()
                    
                }
              
                TextField("First Name", text: $model.firstName)
                    .padding([.leading,.trailing, .top])
                TextField("Last Name", text: $model.lastName)
                    .padding([.leading,.trailing, .top])
                if(model.exsistsError){
                    Text("Already Exsists").font(.callout).foregroundStyle(.red)
                }
                
                HStack{
                    ForEach(colors, id:\.self){color in
                        Button {
                            model.color = color
                        } label: {
                            if model.color == color{
                                ZStack{
                                    Color(color)
                                        .frame(width: 30, height: 30)
                                        .clipShape(Circle())
                                    Color(.white)
                                        .frame(width: 26, height: 26)
                                        .clipShape(Circle())
                                    Color(color)
                                        .frame(width: 20, height: 20)
                                        .clipShape(Circle())
                                    
                                }
                                
                            }else{
                                Color(color)
                                    .frame(width: 20, height: 20)
                                    .clipShape(Circle())
                            }
                            
                            
                        }
                        .padding([.top], 20)
                        .padding(5)
                    }
                }
                
               
                Spacer()
            }
            .navigationDestination(isPresented: $model.crop, destination: {
                switch model.imageState {
                case .success(let image):
                    PhotoCropper(viewModel: PhotoCropperViewModel(image: image),scale: $model.scale, offset: $model.offset)
                case .empty, .loading, .failure:
                    EmptyView()
                    
                }
            })
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        presentationMode.wrappedValue.dismiss()
                    } label: {
                        Text( "Cancel")
                    }

                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Create") {
                        do{
                            try model.addUser( context: context)
                        }catch PlayerEntryError.userExsists{
                            model.exsistsError = true
                            return
                        }
                        catch{
                            print("error")
                        }
                        
                        presentationMode.wrappedValue.dismiss()
                    }
                }
            }
            .interactiveDismissDisabled()
            .padding()
            
        }
        
    }
}

#Preview {
    PlayerEntryView()
}
