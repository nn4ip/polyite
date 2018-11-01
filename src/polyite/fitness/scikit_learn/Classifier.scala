package polyite.fitness.scikit_learn

import polyite.fitness.Feature
import polyite.util.fitness.python.PythonUtil
import java.io.File
import polyite.schedule.Schedule
import polyite.fitness.FeatureVect
import polyite.util.fitness.python.PythonWrapper
import java.util.logging.Logger
import polyite.fitness.Prediction
import polyite.schedule.DomainCoeffInfo
import polyite.util.SCoPMetrics

object Classifier {
  val myLogger : Logger = Logger.getLogger("")

  object LearningAlgorithms extends Enumeration {
    val CART, RANDOM_FOREST = Value

    def toPyStr(v : LearningAlgorithms.Value) : String = {
      if (v == CART)
        return "LearningAlgorithms.cart"
      return "LearningAlgorithms.random_forest"
    }
  }

  class RandomForestConfig(val nTree : Int, val maxFeatures : Int) {

    def toPyStr() : String = f"RandomForestsConfig(${nTree}, ${maxFeatures})"
  }
}

/**
  * A classifier is created from a given learning set, consisting of file paths of population CSVs generated by
  * {@code polyite.util.fitness.FitnessCalculator}.
  * @param learningSet List of files from which the training samples will be loaded.
  * @param minSamplesLeaf Minimum number of samples that must be located in a leaf of a decision tree.
  * @param learningAlgorithm Allows to choose between CART and random forests.
  * @param randomForestConfig If random forests is selected as the learning algorithm, {@code randomForstConfig} configures
  * the learner. Set this to {@code None}, otherwise.
  * @param pythonVEnvLocation The machine learning relies on a Python session that runs in an interactive Python 3 session.
  * In order to provide access to scikit-learn the path to a virtual Python environment can be provided. In the virtual
  * environment scikit-learn (http://scikit-learn.org/) and its dependencies must be installed.
  */
class Classifier(features : List[Feature],
    learningSet : List[File],
    minSamplesLeaf : Int,
    learningAlgorithm : Classifier.LearningAlgorithms.Value,
    randomForestConfig : Option[Classifier.RandomForestConfig],
    pythonVEnvLocation : Option[File]) {

  private val python : PythonWrapper = new PythonWrapper(pythonVEnvLocation)

  private var destroyed : Boolean = false

  override def finalize() {
    if (!destroyed)
      destroy()
  }

  def destroy() {
    destroyed = true
    python.destroy()
  }

  python.runScript(getClass.getResource("init.py").getPath)
  val command : String = "clf = learn(" + PythonUtil.mkPythonStrList(this.features.sorted) + ", " +
    PythonUtil.mkPythonStrList(learningSet.map(_.getAbsolutePath)) + ", False, " +
    minSamplesLeaf + ", " + Classifier.LearningAlgorithms.toPyStr(learningAlgorithm) + ", " +
    randomForestConfig.map(_.toPyStr()).getOrElse("None") + ")"
  Classifier.myLogger.info(command)
  python.eval(command)
  python.eval("clfTest = str(clf is not None)")
  assert(python.getValue("clfTest").equals("True"))

  /**
    * Export the learned decision tree to a .dot file.
    */
  def exportTree(dotFile : File) {
    assert(!destroyed)
    python.eval("with open(\"" + dotFile.getAbsolutePath + "\", 'w') as f:\n  tree.export_graphviz(clf, out_file=f, feature_names="
      + PythonUtil.mkPythonStrList(features.sorted) + ", class_names=list(map(lambda i: str(i), [\"bad\", \"good\"])), filled=True, rounded=True, special_characters=True)\n")
  }

  /**
    * Make predictions for the given set of schedules and their feature vectors.
    */
  def predict(scheds : Map[Schedule, FeatureVect]) : Map[Schedule, Prediction] = {
    return scheds.map((t : (Schedule, FeatureVect)) => {
      (t._1, predict(t._2))
    })
  }

  /**
    * Make a prediction for the given feature vector.
    */
  def predict(fVect : FeatureVect) : Prediction = {
    assert(!destroyed)
    val featureVals : List[Double] = fVect.getVect().map(_._2)
    val fVectStr : String = f"[${PythonUtil.mkPythonStrList(featureVals)}]"
    python.eval(f"currPred=clf.predict(${fVectStr})")
    python.eval(f"currPred=currPred[0]")
    val pred : Prediction.PerfClass.Value = python.getValue("currPred").toString.toDouble.intValue() match {
      case 0 => Prediction.PerfClass.BAD
      case _ => Prediction.PerfClass.GOOD
    }
    python.eval("currPred = None")
    python.getValue("currPred")
    return new Prediction(fVect, Some(pred))
  }

  private def rescaleFeatures(l : List[List[Double]]) : List[List[Double]] = {
    val maxima : List[Double] = (0 until features.length).map((i : Int) => {
      l.map(_(i)).max
    }).toList
    val minima : List[Double] = (0 until features.length).map((i : Int) => {
      l.map(_(i)).min
    }).toList
    val result : List[List[Double]] = l.map { (fVect : List[Double]) =>
      {
        fVect.zipWithIndex.map((t : (Double, Int)) => {
          if (minima(t._2) != maxima(t._2))
            (t._1 - minima(t._2)) / (maxima(t._2) - minima(t._2))
          else
            t._1
        })
      }
    }
    return result
  }
}