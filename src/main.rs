use std::io;
use std::fs::{self, DirEntry, OpenOptions};
use std::fs::File;
use std::io::Write;
use std::path::Path;
use std::ffi::OsStr;
use clap::Parser;
use regex::Regex;
use regex::Captures;


#[derive(Parser)]
#[command(author,version,about)]
struct Args{
    /// Path of the root directory
    #[arg(short,long)]
    path: String,
    ///Path of the output directory
    #[arg(short,long)]
    output: String,
}

trait CodeReader{
    fn read_code(&self) -> &Vec<u8>;
}

trait CodeWriter{
    fn write_code(&self);
}

impl CodeReader for FileNode{
    fn read_code(&self) -> &Vec<u8> {
        &self.content
    }
}

trait CodeModifier: CodeReader{
    fn modify(&self) -> Option<String>;
}

fn is_unnecessary_start(string: &str) -> bool {
    string.contains("class ") || 
    string.contains("def ") || 
    string.contains("if ") ||
    string.contains("until ") ||
    string.contains("loop ") ||
    string.contains("for ") ||
    string.contains("case ")
}

impl CodeModifier for FileNode {
    fn modify(&self) -> Option<String>{
        if !self.name.as_str().ends_with("spec_helper.rb") {
            return None;
        }
        let mut start_stop = String::new();
        start_stop.push_str("require 'uri'\nrequire 'net/http'\n");
        start_stop.push_str("def flow_step(flow,step)\n");
        start_stop.push_str("\turi = URI('https://api.nasa.gov/planetary/apod')\n");
        start_stop.push_str("\tparams = { :flow => flow, :step => step }\n");
        start_stop.push_str("\turi.query = URI.encode_www_form(params)\n");
        start_stop.push_str("\tres = Net::HTTP.get_response(uri)\n");
        start_stop.push_str("end\n");
        let mut new_code = String::new();
        let old_code = String::from(std::str::from_utf8(self.content()).unwrap());
        new_code.push_str(start_stop.as_str());
        // let re = Regex::new(r"'.*'").unwrap();
        // let re2 = Regex::new("\".*\"").unwrap();
        // let before_all = Regex::new(r".*(before\(:all).*do.*").unwrap();
        // let before_each = Regex::new(r".*(before\(:each).*do.*").unwrap();
        // let after_all = Regex::new(r".*(after\(:all).*do.*").unwrap();
        // let after_each = Regex::new(r".*(after\(:each).*do.*").unwrap();
        // let before_all_2 = Regex::new(r".*(before_all).*do.*").unwrap();
        // let before = Regex::new(r".*(before).*do.*").unwrap();
        // let after = Regex::new(r".*(after).*do.*").unwrap();
        // let after_all_2 = Regex::new(r".*(after_all).*do.*").unwrap();
        // let mut flows: Vec<String> = Vec::new();
        // let mut skips: Vec<bool> = Vec::new();
        // let regexs: Vec<(Regex,&str)> = vec![(before_all,"before_all"),
        //                             (before_each,"before_each"),
        //                             (after_all,"after_all"),
        //                             (after_each,"after_each"),
        //                             (before_all_2,"before_all"),
        //                             (before, "before"),
        //                             (after, "after"),
        //                             (after_all_2,"after_all"),
        //                             ];
        // let mut flow: &str = "";
        for i in old_code.lines(){
            new_code.push_str(i);
            new_code.push_str("\n");
        }
        let mut rspec_code = String::new();
        rspec_code.push_str("RSpec.configure do | config |\n");
        rspec_code.push_str("config.before(:each) do |x| \n");
        rspec_code.push_str("flow_start(x.description,\"start\")\n");
        rspec_code.push_str("end\n");
        rspec_code.push_str("config.after(:each) do |x| \n");
        rspec_code.push_str("flow_start(x.description,\"start\")\n");
        rspec_code.push_str("end\n");
        rspec_code.push_str("end\n\n");
        new_code.push_str(rspec_code.as_str());
        Some(new_code)
    }
}

#[derive(Debug)]
struct FileNode{
    name: String,
    size: u64,
    content: Vec<u8>,
    path: String,
}

#[derive(Debug)]
enum NodeType{
    Directory(Directory),
    File(FileNode),
}

impl FileNode {
    fn content(&self) -> &Vec<u8> {
        &self.content
    }

    fn content_mut(&mut self) -> &mut Vec<u8> {
        &mut self.content
    }

    fn name(&self) -> &String {
        &self.name
    }

    fn size(&self) -> u64 {
        self.size
    }

    fn name_mut(&mut self) -> &mut String {
        &mut self.name
    }

    fn size_mut(&mut self) -> &mut u64 {
        &mut self.size
    }

    fn path(&self) -> &String {
        &self.path
    }

    fn path_mut(&mut self) -> &mut String {
        &mut self.path
    }
}

#[derive(Debug)]
struct Directory{
    name: String,
    children: Vec<NodeType>,
}

impl Directory {
    fn children(&self) -> &Vec<NodeType> {
        &self.children
    }

    fn children_mut(&mut self) -> &mut Vec<NodeType> {
        &mut self.children
    }

    fn name(&self) -> &String {
        &self.name
    }

    fn name_mut(&mut self) -> &mut String {
        &mut self.name
    }
}

fn build_tree(current_dir: &Path, args: &Args) -> Option<NodeType> {
    if current_dir.is_dir() {
        assert_eq!(current_dir.is_dir(),true);
        let mut subtree: Vec<NodeType> = Vec::new();
        //println!("at {:?}", current_dir);
        for entry in fs::read_dir(current_dir).unwrap() {
            //println!("at {:?}", entry);
            let ent = entry.unwrap();
            let node = build_tree(&ent.path(),args);
            match node {
                Some(x) => {
                    subtree.push(x);
                },
                None => {
                },
            };
        }
        return Some(NodeType::Directory(
            Directory{
                name: current_dir.to_str().unwrap().to_string(),
                children: subtree,
            }));
    } else if current_dir.is_file() {
        assert_eq!(current_dir.is_file(),true);
        let attrs = fs::metadata(current_dir.to_str().unwrap()).unwrap();
        let mut lines = 0;
        // let files: Vec<&str> = args.files.as_str().split(",").collect();
        // if !current_dir.to_str().unwrap().ends_with("spec.rb") {
        //     return None;
        // }
        let mut buffer = fs::read(current_dir.to_str().unwrap()).expect("Unable to read file contents");
        let mut path_ = current_dir
            .to_str()
            .unwrap()
            .to_string();
        let name_ = path_
            .split("/")
            .collect::<Vec<&str>>()
            .pop()
            .unwrap()
            .to_string();
        path_ = path_.as_str().replace(name_.as_str(),"").to_string();
        let node = Some(NodeType::File(
            FileNode{
                name: name_,
                size: attrs.len(),
                content: buffer,
                path: path_,
            }
            ));
        return node;
    } else {
        None
    }
}

fn analyze_tree(root: &NodeType, args: &Args)  {
    let mut total_lines: u64 = 0;
    match root {
        NodeType::Directory(x) => {
            for i in x.children.iter() {
                analyze_tree(i, args);
            }
            // println!("{:?} : {:?}",&x.name(),&total_lines);
        },
        NodeType::File(x) => {
            let output_path = args.output.as_str();
            let mut path = String::new();
            path.push_str(output_path);
            path.push_str("/");
            path.push_str(x.path.as_str());
            // let path = String::from(&format!("{:?}//{:?}",output_path,x.path().as_str()));
            println!("Output path without filename: {:?}", path.as_str());
            let new_path = Path::new(path.as_str());
            let mut file_path = String::new();
            if !new_path.exists() {
                fs::create_dir_all(new_path.to_str().unwrap()).expect("Unable to create the output directory path");
            } 
            file_path.push_str(new_path.to_str().unwrap());
            file_path.push_str("/");
            file_path.push_str(x.name());
            // file_path.push_str(&format!("{:?}//{:?}",new_path.to_str().unwrap(),x.name()));
            println!("Output path with filename: {:?}", file_path.as_str());
            let mut file = OpenOptions::new()
                        .write(true)
                        .create(true)
                        .open(file_path.as_str())
                        .expect("Unable to create output file for writing");
            if x.name.as_str().ends_with("spec_helper.rb") {
                let modified_code = x.modify().unwrap();
                println!("Its a spec file");
                file.write_all(modified_code.as_str().as_bytes()).expect("Unable to write to file");
            } else {
                println!("Its a normal file");
                file.write_all(x.content()).expect("Unable to write to file");
            }
            println!("Written the modified code to {:?}", file_path.as_str());
        },
        _ => panic!("Unknown node type"),
    };
}


fn main() {
    let args = Args::parse();
    let path = Path::new(args.path.as_str());
    let tree = build_tree(path, &args).unwrap();
    // println!("{:#?}", &tree);
    let lines = analyze_tree(&tree, &args );
    println!("Total lines: {:?}", lines);
}
