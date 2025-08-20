pipeline {

    agent any

    /*
    options {
        disableConcurrentBuilds()
    }
    */

    stages {
        stage('Test') {
            steps {
                echo 'Testing...'
                withMaven(maven: 'mvn3.6', jdk:'jdk8') {
                    sh 'mvn compile test'
                }
            }
        }
        stage('Install') {
            steps {
                withMaven(maven: 'mvn3.6', jdk:'jdk8') {
                    sh 'mvn install -Dmaven.test.skip=true'
                }
            }
        }
        stage('Package') {
            steps {
                echo 'Packaging Provider...'
                withMaven(maven: 'mvn3.6', jdk:'jdk8') {
                    sh 'mvn package spring-boot:repackage -pl maven-project -Dmaven.test.skip=true'
                }
            }
        }
        stage('Deploy') {
            steps {
                echo 'Deploying...'
                sh '''
                        scp maven-project/target/maven-project.jar username@hostname:~/remote-workspace/app.jar
                        sleep 1
                        ssh username@hostname "cd remote-workspace; ./startup.sh"
                '''
            }
        }
    }
}
